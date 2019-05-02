<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );

	return false;
} );
