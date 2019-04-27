<?php // This handler only works for the build docker container for testing only. It does not the lambda event types.
$request = file_get_contents( "php://stdin" );
$response = [
	"statusCode" => 200,
	"headers" => [],
	"body" => $request,
	"isBase64Encoded" => false

];
file_put_contents("php://stdout", $request);
