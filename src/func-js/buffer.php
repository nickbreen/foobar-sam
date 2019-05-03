<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	file_put_contents("php://stderr", print_r($_SERVER, true));

	return false;
} );
