const {spawn} = require('child_process');
const parser = require('http-string-parser');

function handler(event, context) {
    // Sets some sane defaults here so that this function doesn't fail when it's not handling a HTTP request from
    // API Gateway.
    const requestMethod = event.httpMethod || 'GET';
    const serverName = event.headers ? event.headers.Host : '';
    const requestUri = event.path || '';
    const headers = {};

    // Convert all headers passed by API Gateway into the correct format for PHP CGI. This means converting a header
    // such as "X-Test" into "HTTP_X-TEST".
    if (event.headers) {
        Object.keys(event.headers).map(function (key) {
            headers['HTTP_' + key.toUpperCase()] = event.headers[key];
        });
    }

    // Spawn the PHP CGI process with a bunch of environment variables that describe the request.
    const php = spawn('/opt/bin/php-cgi', ['index.php'], {
        env: Object.assign({
            REDIRECT_STATUS: 200,
            REQUEST_METHOD: requestMethod,
            SCRIPT_FILENAME: 'index.php',
            SCRIPT_NAME: '/index.php',
            PATH_INFO: '/',
            SERVER_NAME: serverName,
            SERVER_PROTOCOL: 'HTTP/1.1',
            REQUEST_URI: requestUri
        }, headers)
    });

    // Listen for output on stdout, this is the HTTP response.
    let response = '';
    php.stdout.on('data', function(data) {
        response += data.toString('utf-8');
    });

    // When the process exists, we should have a complete HTTP response to send back to API Gateway.
    php.on('close', function(code) {
        // Parses a raw HTTP response into an object that we can manipulate into the required format.
        const parsedResponse = parser.parseResponse(response);

        // Signals the end of the Lambda function, and passes the provided object back to API Gateway.
        context.succeed({
            statusCode: parsedResponse.statusCode || 200,
            headers: parsedResponse.headers,
            body: parsedResponse.body
        });
    });
}

module.exports = exports = {handler};

