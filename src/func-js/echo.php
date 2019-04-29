<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	return false;
} );
// any of these work
//print file_get_contents("php://input");
stream_copy_to_stream(fopen("php://input", "r"), fopen("php://output", "w"));
//copy("php://input", "php://output");
