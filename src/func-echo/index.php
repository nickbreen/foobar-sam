<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	return false;
} );
// any of these work
stream_copy_to_stream(fopen("php://stdin", "r"), fopen("php://stdout", "w"));
//copy("php://input", "php://output");
