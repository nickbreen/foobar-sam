<?php
header("X-Echo: yes");
stream_copy_to_stream(fopen("php://stdin", "r"), fopen("php://output", "w"));
http_response_code(200);