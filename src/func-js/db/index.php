<?php
ob_start( function () {
	header( 'Content-Length: ' . ob_get_length() );
	header( 'Content-Type: text/plain');

	return false;
} );

$mysqli = new mysqli(
	getenv( 'WP_DATABASE_HOST' ),
	getenv( 'WP_DATABASE_USER' ),
	getenv( 'WP_DATABASE_PASS' ),
	getenv( 'WP_DATABASE_NAME' ),
	getenv( 'WP_DATABASE_PORT' )
);

if ($mysqli->connect_errno)
{
	printf( "%s: %s\r\n", $mysqli->connect_errno, $mysqli->connect_error);
}
else
{
	$res = $mysqli->query("SELECT 1");
	for ($i = 0; $i < $res->num_rows; $i++)
	{
		$res->data_seek($i);
		$row = $res->fetch_row();
		printf( "%02d:%s\r\n", $i, $row[0]);
	}
}
$mysqli->close();
