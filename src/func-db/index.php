<?php
ob_start( function ($buffer) {
	header( 'Content-Length: ' . ob_get_length() );
	header( 'Content-Type: application/json');

    return json_encode((object) array("headers" => (object) array(), "body" => base64_encode($buffer), "isBase64Encoded" => true));
} );

$host = getenv( 'WP_DATABASE_HOST' );
$user = getenv( 'WP_DATABASE_USER' );
$pass = getenv( 'WP_DATABASE_PASS' );
$name = getenv( 'WP_DATABASE_NAME' );
$port = getenv( 'WP_DATABASE_PORT' );

printf("db://%s:%s@%s:%s/%s\r\n", $user, $pass, $host, $port, $name);

$mysqli = new mysqli( $host, $user, $pass, $name, $port );

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
