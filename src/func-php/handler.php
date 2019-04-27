<?php
//require_once 'wp-content/vendor/autoload.php';
//require_once 'wp/index.php';


$request = json_decode( file_get_contents( "php://stdin" ) );

$request_entity = $request['isBase64Encoded'] ? base64_decode($request_entity['body']) : $request_entity['body'];

$response = [
	"statusCode" => 200,
	"headers" => [],
	"body" => $request_entity,
	"isBase64Encoded" => false

];
file_put_contents("php://stdout", json_encode($response));
