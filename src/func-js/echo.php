<?php
ob_start();
print file_get_contents("php://input");
//stream_copy_to_stream(STDIN, STDOUT);
//copy("php://input", "php://output");
header('Content-Length: ' . ob_get_length());
ob_end_flush();