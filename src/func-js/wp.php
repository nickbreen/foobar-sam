<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	return false;
} );
require_once '/opt/wp-content/vendor/autoload.php';
require_once '/opt/wp/index.php';
