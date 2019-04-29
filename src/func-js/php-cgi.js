const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');
const fs = require('fs');

function extractPhpHeaderEnvironmentVariablesFromEvent(event)
{
    return Object.entries(event.headers).reduce((acc, [header, value]) =>
    {
        acc['HTTP_' + header.toUpperCase().replace(/-/g, '_')] = value;
        return acc;
    }, {});
}

function extractPhpSpecificEnvironmentVariableFromEvent(event)
{
    return {
        REDIRECT_STATUS: 200,
        SCRIPT_FILENAME: process.env.SCRIPT,
        REQUEST_URI: event.path
    };
}

function extractCgiEnvironmentVariablesFromEvent(contentLength, event)
{
    return {
        CONTENT_LENGTH: contentLength,
        CONTENT_TYPE: event.headers['Content-Type'] || 'application/octet-stream',
        GATEWAY_INTERFACE: '1.1',
        PATH_INFO: event.path,
        PATH_TRANSLATED: event.path,
        QUERY_STRING: querystring.stringify(event.queryStringParameters),
        REMOTE_ADDR: event.requestContext.identity.sourceIp,
        REMOTE_HOST: event.requestContext.identity.sourceIp,
        REMOTE_IDENT: null,
        REMOTE_USER: null,
        REQUEST_METHOD: event.httpMethod,
        SCRIPT_NAME: process.env.SCRIPT,
        SERVER_NAME: event.headers['Host'],
        SERVER_PORT: event.headers['X-Forwarded-Port'],
        SERVER_PROTOCOL: event.protocol,
        SERVER_SOFTWARE: process.env['_HANDLER']
    };
}

function extractEnvironmentVariablesFromEvent(event, contentLength)
{
    return Object.assign(
        {},
        process.env,
        extractCgiEnvironmentVariablesFromEvent(contentLength, event),
        extractPhpSpecificEnvironmentVariableFromEvent(event),
        extractPhpHeaderEnvironmentVariablesFromEvent(event));
}

function getResponseHeader(response, headerName)
{
    return Object.entries(response.headers)
        .find(([header]) => header.toLowerCase() === headerName.toLowerCase()) || [];
}

function base64EncodeBodyIfRequired(response)
{
    const [, contentType] = getResponseHeader(response, 'content-type');

    const mimeType = MIMEType.parse(contentType);

    const base64Encoded = mimeType.type !== 'text';

    const responseBody = base64Encoded && response.body ?
        Buffer.from(response.body, 'utf8').toString('base64') :
        response.body;

    return {base64Encoded, responseBody};
}

function base64DecodeBodyIfRequired(event)
{
    return event.isBase64Encoded && event.body ?
        Buffer.from(event.body, 'base64').toString('utf8') :
        event.body;
}

function extractBodyAndEnvironmentVariablesFromEvent(event)
{
    const requestBody = base64DecodeBodyIfRequired(event);
    const contentLength = requestBody ? requestBody.length : null;
    const env = extractEnvironmentVariablesFromEvent(event, contentLength);
    return {requestBody, env};
}

async function handler(event, context)
{
    if (!process.env.SCRIPT)
    {
        throw new Error("No script specified in environment variable SCRIPT: " + process.env.SCRIPT);
    }

    fs.accessSync(process.env.SCRIPT, fs.constants.R_OK);

    const {requestBody, env} = extractBodyAndEnvironmentVariablesFromEvent(event);

    const args = [
        '-d', 'php.ini',
        '-d', 'memory_limit=' + context.memoryLimitInMB + 'M',
        '-d', 'max_execution_time=' + Math.trunc(context.getRemainingTimeInMillis() / 1000),
        '-d', 'default_mimetype=application/octet-stream',
        '-d', 'default_charset=UTF-8',
        '-d', 'upload_max_filesize=2M',
        '-d', 'cgi.discard_path=1',
        '-d', 'display_errors=On',
        '-d', 'display_startup_errors=On',
        '-d', 'cgi.rfc2616_headers=1',
        '-d', 'session.save_handler', // unset
        '-d', 'opcache.enable=1',
        '-d', 'enable_post_data_reading=Off' // this will probably break WordPress
    ];
    const opts = {cwd: process.env.LAMBDA_TASK_ROOT, env: env, input: requestBody};

    const php = spawnSync('/opt/bin/php-cgi', args, opts);

    if (php.status === 0)
    {
        let cgiResponse = php.stdout.toString('utf8');

        const response = parseResponse(cgiResponse);

        const {base64Encoded, responseBody} = base64EncodeBodyIfRequired(response);

        return {
            statusCode: response.statusCode || 200,
            headers: response.headers,
            body: responseBody,
            isBase64Encoded: base64Encoded
        };
    }
    else
    {
        throw new Error(php.stderr.toString('utf8'));
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};
