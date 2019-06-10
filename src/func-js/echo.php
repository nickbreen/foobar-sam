<?php
header("Content-Type: application/json");
stream_copy_to_stream(fopen("php://input", "r"), fopen("php://output", "w"));
