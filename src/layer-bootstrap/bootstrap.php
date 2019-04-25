#!/opt/bin/php -c/opt/etc/php.ini
<?php

error_reporting( E_ALL | E_STRICT );

/* https://gist.github.com/henriquemoody/6580488 */
$http_codes = [
	100 => 'Continue',
	101 => 'Switching Protocols',
	102 => 'Processing',
	200 => 'OK',
	201 => 'Created',
	202 => 'Accepted',
	203 => 'Non-Authoritative Information',
	204 => 'No Content',
	205 => 'Reset Content',
	206 => 'Partial Content',
	207 => 'Multi-Status',
	208 => 'Already Reported',
	226 => 'IM Used',
	300 => 'Multiple Choices',
	301 => 'Moved Permanently',
	302 => 'Found',
	303 => 'See Other',
	304 => 'Not Modified',
	305 => 'Use Proxy',
	306 => 'Switch Proxy',
	307 => 'Temporary Redirect',
	308 => 'Permanent Redirect',
	400 => 'Bad Request',
	401 => 'Unauthorized',
	402 => 'Payment Required',
	403 => 'Forbidden',
	404 => 'Not Found',
	405 => 'Method Not Allowed',
	406 => 'Not Acceptable',
	407 => 'Proxy Authentication Required',
	408 => 'Request Timeout',
	409 => 'Conflict',
	410 => 'Gone',
	411 => 'Length Required',
	412 => 'Precondition Failed',
	413 => 'Request Entity Too Large',
	414 => 'Request-URI Too Long',
	415 => 'Unsupported Media Type',
	416 => 'Requested Range Not Satisfiable',
	417 => 'Expectation Failed',
	418 => 'I\'m a teapot',
	419 => 'Authentication Timeout',
	422 => 'Unprocessable Entity',
	423 => 'Locked',
	424 => 'Failed Dependency',
	425 => 'Unordered Collection',
	426 => 'Upgrade Required',
	428 => 'Precondition Required',
	429 => 'Too Many Requests',
	431 => 'Request Header Fields Too Large',
	444 => 'No Response',
	449 => 'Retry With',
	450 => 'Blocked by Windows Parental Controls',
	451 => 'Unavailable For Legal Reasons',
	494 => 'Request Header Too Large',
	495 => 'Cert Error',
	496 => 'No Cert',
	497 => 'HTTP to HTTPS',
	499 => 'Client Closed Request',
	500 => 'Internal Server Error',
	501 => 'Not Implemented',
	502 => 'Bad Gateway',
	503 => 'Service Unavailable',
	504 => 'Gateway Timeout',
	505 => 'HTTP Version Not Supported',
	506 => 'Variant Also Negotiates',
	507 => 'Insufficient Storage',
	508 => 'Loop Detected',
	509 => 'Bandwidth Limit Exceeded',
	510 => 'Not Extended',
	511 => 'Network Authentication Required',
	598 => 'Network read timeout error',
	599 => 'Network connect timeout error'
];

$AWS_LAMBDA_RUNTIME_API = getenv( 'AWS_LAMBDA_RUNTIME_API' );

function start_webserver() {
	$SERVER_STARTUP_TIMEOUT = 1000000; // 1 second

	$pid = pcntl_fork();
	switch ( $pid ) {
		case - 1:
			die( "Failed to fork webserver process\n" );

		case 0:
			// exec the command
			$workingDir = getenv( 'LAMBDA_TASK_ROOT' );
			$router     = getenv( '_HANDLER' );
			$cmd = "php -c /opt/etc/php.ini -S localhost:8000 -t ${workingDir} ${router} 2>/tmp/err 1>/tmp/out";
			shell_exec( $cmd );
//			exit(69); //EX_UNAVAILABLE
            exit;

		default:
			// Wait for child server to start
			$start = microtime( true );

			do {
				if ( microtime( true ) - $start > $SERVER_STARTUP_TIMEOUT ) {
					die( "Webserver failed to start within one second\n" );
				}

				usleep( 1000 );
				$fp = @fsockopen( 'localhost', 8000, $errno, $errstr, 1 );
			} while ( $fp == false );

			fclose( $fp );
	}
}

function fail( $AWS_LAMBDA_RUNTIME_API, $invocation_id, $message ) {
	$ch = curl_init( "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$invocation_id/response" );

	$response = array();

	$response['statusCode'] = 500;
	$response['body']       = $message;

	$response_json = json_encode( $response );

	curl_setopt( $ch, CURLOPT_CUSTOMREQUEST, 'POST' );
	curl_setopt( $ch, CURLOPT_RETURNTRANSFER, true );
	curl_setopt( $ch, CURLOPT_POSTFIELDS, $response_json );
	curl_setopt( $ch, CURLOPT_HTTPHEADER, array(
		'Content-Type: application/json',
		'Content-Length: ' . strlen( $response_json )
	) );

	curl_exec( $ch );
	curl_close( $ch );
}

start_webserver();

while ( true ) {
	$ch = curl_init( "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/next" );

	curl_setopt( $ch, CURLOPT_FOLLOWLOCATION, true );
	curl_setopt( $ch, CURLOPT_FAILONERROR, true );

	$invocation_id = '';

	curl_setopt( $ch, CURLOPT_HEADERFUNCTION, function ( $ch, $header ) use ( &$invocation_id ) {
		if ( ! preg_match( '/:\s*/', $header ) ) {
			return strlen( $header );
		}

		[ $name, $value ] = preg_split( '/:\s*/', $header, 2 );

		if ( strtolower( $name ) == 'lambda-runtime-aws-request-id' ) {
			$invocation_id = trim( $value );
		}

		return strlen( $header );
	} );

	$body = '';

	curl_setopt( $ch, CURLOPT_WRITEFUNCTION, function ( $ch, $chunk ) use ( &$body ) {
		$body .= $chunk;

		return strlen( $chunk );
	} );

	curl_exec( $ch );

	if ( curl_error( $ch ) ) {
		die( 'Failed to fetch next Lambda invocation: ' . curl_error( $ch ) . "\n" );
	}

	if ( $invocation_id == '' ) {
		die( "Failed to determine Lambda invocation ID\n" );
	}

	curl_close( $ch );

	if ( ! $body ) {
		die( "Empty Lambda invocation response\n" );
	}

	$event = json_decode( $body, true );

	if ( ! array_key_exists( 'requestContext', $event ) ) {
		fail( $AWS_LAMBDA_RUNTIME_API, $invocation_id, 'Event is not an API Gateway request' );
		continue;
	}

	$uri = $event['path'];

	if ( array_key_exists( 'multiValueQueryStringParameters', $event ) && $event['multiValueQueryStringParameters'] ) {
		$first = true;
		foreach ( $event['multiValueQueryStringParameters'] as $name => $values ) {
			foreach ( $values as $value ) {
				if ( $first ) {
					$uri   .= "?";
					$first = false;
				} else {
					$uri .= "&";
				}

				$uri .= $name;

				if ( $value != '' ) {
					$uri .= '=' . $value;
				}
			}
		}
	}

	$ch = curl_init( "http://localhost:8000$uri" );

	curl_setopt( $ch, CURLOPT_FOLLOWLOCATION, true );

	if ( array_key_exists( 'multiValueHeaders', $event ) ) {
		$headers = array();

		foreach ( $event['multiValueHeaders'] as $name => $values ) {
			foreach ( $values as $value ) {
				array_push( $headers, "${name}: ${value}" );
			}
		}

		curl_setopt( $ch, CURLOPT_HTTPHEADER, $headers );
	}

	curl_setopt( $ch, CURLOPT_CUSTOMREQUEST, $event['httpMethod'] );

	if ( array_key_exists( 'body', $event ) ) {
		$body = $event['body'];
		if ( array_key_exists( 'isBase64Encoded', $event ) && $event['isBase64Encoded'] ) {
			$body = base64_decode( $body );
		}
	} else {
		$body = '';
	}

	if ( strlen( $body ) > 0 ) {
		if ( $event['httpMethod'] === 'POST' ) {
			curl_setopt( $ch, CURLOPT_POSTFIELDS, $body );
		}
		curl_setopt( $ch, CURLOPT_INFILESIZE, strlen( $body ) );
		curl_setopt( $ch, CURLOPT_READFUNCTION, function ( $ch, $fd, $length ) use ( $body ) {
			return $body;
		} );
	}

	$response                      = array();
	$response['multiValueHeaders'] = array();
	$response['body']              = '';

	curl_setopt( $ch, CURLOPT_HEADERFUNCTION, function ( $ch, $header ) use ( &$response ) {
		if ( preg_match( '/HTTP\/1.1 (\d+) .*/', $header, $matches ) ) {
			$response['statusCode'] = intval( $matches[1] );

			return strlen( $header );
		}

		if ( ! preg_match( '/:\s*/', $header ) ) {
			return strlen( $header );
		}

		[ $name, $value ] = preg_split( '/:\s*/', $header, 2 );

		$name  = trim( $name );
		$value = trim( $value );

		if ( $name == '' ) {
			return strlen( $header );
		}

		if ( ! array_key_exists( $name, $response['multiValueHeaders'] ) ) {
			$response['multiValueHeaders'][ $name ] = array();
		}

		array_push( $response['multiValueHeaders'][ $name ], $value );

		return strlen( $header );
	} );

	curl_setopt( $ch, CURLOPT_WRITEFUNCTION, function ( $ch, $chunk ) use ( &$response ) {
		$response['body'] .= $chunk;

		return strlen( $chunk );
	} );

	curl_exec( $ch );
	curl_close( $ch );

	$ch = curl_init( "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$invocation_id/response" );

	$isALB = array_key_exists( "elb", $event['requestContext'] );
	if ( $isALB ) { // Add Headers For ALB
		$status = $response["statusCode"];
		if ( array_key_exists( $status, $http_codes ) ) {
			$response["statusDescription"] = "$status " . $http_codes[ $status ];
		} else {
			$response["statusDescription"] = "$status Unknown";
		}
		$response["isBase64Encoded"] = false;
	}
	$response_json = json_encode( $response );
	curl_setopt( $ch, CURLOPT_CUSTOMREQUEST, 'POST' );
	curl_setopt( $ch, CURLOPT_RETURNTRANSFER, true );
	curl_setopt( $ch, CURLOPT_POSTFIELDS, $response_json );
	if ( ! $isALB ) {
		curl_setopt( $ch, CURLOPT_HTTPHEADER, array(
			'Content-Type: application/json',
			'Content-Length: ' . strlen( $response_json )
		) );
	}
	curl_exec( $ch );
	curl_close( $ch );
}
