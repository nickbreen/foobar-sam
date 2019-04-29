<?php stream_copy_to_stream(fopen("php://input", "r"), fopen("php://output", "w"));
// This handler only works for the build docker container for testing only. It does not process lambda events.
