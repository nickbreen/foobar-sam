<?php
$request = json_decode( file_get_contents( "php://stdin" ) );

$request_entity = $request->isBase64Encoded ? base64_decode($request->body) : $request->body;

$response = [
	"statusCode"      => 200,
	"headers"         => [],
	"body"            => $request_entity,
	"isBase64Encoded" => false

];
file_put_contents( "php://stdout", json_encode( $response ) );
