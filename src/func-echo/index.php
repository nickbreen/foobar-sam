<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );
	var_dump(headers_list());
	return false;
} );
header('X-Test: yes');
stream_copy_to_stream(fopen("php://stdin", "r"), fopen("php://output", "w"));
http_response_code(200);