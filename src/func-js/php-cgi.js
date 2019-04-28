const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');

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
        SCRIPT_FILENAME: process.env.SCRIPT || "index.php",
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
        SCRIPT_NAME: process.env.SCRIPT || "index.php",
        SERVER_NAME: event.headers['Host'],
        SERVER_PORT: event.headers['X-Forwarded-Port'],
        SERVER_PROTOCOL: event.protocol,
        SERVER_SOFTWARE: process.env['_HANDLER']
    };
}

function extractEnvironmentVariablesFromEvent(contentLength, event)
{
    return Object.assign(
        {},
        process.env,
        extractCgiEnvironmentVariablesFromEvent(contentLength, event),
        extractPhpSpecificEnvironmentVariableFromEvent(event),
        extractPhpHeaderEnvironmentVariablesFromEvent(event));
}

function base64EncodeBodyIfRequired(response)
{
    const [, contentType] = Object.entries(response.headers)
        .find(([header]) => header.toLowerCase() === 'content-type') || [];

    const mimeType = MIMEType.parse(contentType);

    const base64Encoded = mimeType.type !== 'text';

    const body = base64Encoded ?
        Buffer.from(response.body, 'utf8').toString('base64') :
        JSON.stringify(response.body);
    return {base64Encoded, body};
}

function base64DecodeBodyIfRequired(event)
{
    return event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;
}

function extractBodyAndEnvironmentVariablesFromEvent(event)
{
    const body = base64DecodeBodyIfRequired(event);
    const contentLength = body ? body.length : null;
    const env = extractEnvironmentVariablesFromEvent(contentLength, event);
    return {body, env};
}

async function handler(event, context)
{
    const {body, env} = extractBodyAndEnvironmentVariablesFromEvent(event);

    const php = spawnSync(
        '/opt/bin/php-cgi',
        [
            '-d', 'php.ini',
            '-d', 'memory_limit=' + context.memoryLimitInMB + 'M',
            '-d', 'max_execution_time=' + Math.trunc(context.getRemainingTimeInMillis() / 1000),
            '-d', 'default_mimetype=application/octet-stream',
            '-d', 'default_charset=UTF-8',
            '-d', 'upload_max_filesize=2M',
            '-d', 'cgi.discard_path=1',
            '-d', 'cgi.rfc2616_headers=1',
            '-d', 'session.save_handler', // unset
            '-d', 'opcache.enable=1'
        ],
        {cwd: process.env.LAMBDA_TASK_ROOT, env: env, input: body});

    if (php.status === 0)
    {
        const response = parseResponse(php.stdout.toString('utf8'));

        const {base64Encoded, body} = base64EncodeBodyIfRequired(response);

        return {
            statusCode: response.statusCode || 200,
            headers: response.headers,
            body: body,
            isBase64Encoded: base64Encoded
        };
    }
    else
    {
        throw new Error(php.stderr.toString('utf8'));
    }
}

module.exports = exports = {handler};
