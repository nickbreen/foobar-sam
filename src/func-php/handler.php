<?php
$request = json_decode( file_get_contents( "php://stdin" ) );

$request_entity = $request->isBase64Encoded ? base64_decode($request->body) : $request->body;

$response_entity = $request->isBase64Encoded ? base64_encode($request_entity) : $request_entity;

$response = [
	"statusCode"      => 200,
	"headers"         => [],
	"body"            => $response_entity,
	"isBase64Encoded" => $request->isBase64Encoded
];

file_put_contents( "php://stdout", json_encode( $response ) );
