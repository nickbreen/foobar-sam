<?php file_put_contents("php://stdout", file_get_contents( "php://stdin" ) );
// This handler only works for the build docker container for testing only. It does not the lambda event types.
