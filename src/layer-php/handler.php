<?php
ob_start( function ($buf)
{
	header( 'Content-Length: ' . ob_get_length() );
    $headers = array_reduce(
       headers_list(),
       function ($acc, $item)
       {
           $header = explode(":", $item);
           $acc[$header[0]] = trim($header[1]);
           return $acc;
       },
       array());
    header_remove();

    $base64EncodedBody = base64_encode($buf);

	return json_encode((object) array(
	    "isBase64Encoded" => TRUE,
	    "statusCode" => http_response_code(),
	    "headers" => $headers,
	    "body" => $base64EncodedBody));
});