<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	return false;
} );
require_once __DIR__ . '/wp-content/vendor/autoload.php';
require_once __DIR__ . '/wp/index.php';
