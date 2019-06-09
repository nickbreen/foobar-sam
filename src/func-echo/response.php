<?php
ob_start( function ($buf)
{
    $headers = array_reduce(
       headers_list(),
       function ($acc, $item)
       {
           $header = explode(":", $item);
           $acc[$header[0]] = $header[1];
           return $acc;
       },
       array());

    $base64EncodedBody = base64_encode($buf);

	return json_encode((object) array(
	    "isBase64Encoded" => TRUE,
	    "statusCode" => http_response_code(),
	    "headers" => $headers,
	    "body" => $base64EncodedBody));
});
