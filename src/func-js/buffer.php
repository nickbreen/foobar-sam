<?php
ob_start( function ($buf) {
	file_put_contents("php://stderr", print_r($buf, true));

	file_put_contents("php://stderr", print_r(headers_list(), true));

	file_put_contents("php://stderr", sprintf("ob_get_length(%d), mb_strlen(%d), strlen(%d)", ob_get_length(), mb_strlen($buf), strlen($buf)));

	//	header_remove('Content-Length'); // api gateway provides this

	return false;
} );
