const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');

function translateHeadersForPhpHeaderEnvironmentVariables(event)
{
    return Object.entries(event.headers).reduce((acc, [header, value]) =>
    {
        acc['HTTP_' + header.toUpperCase().replace(/-/g, '_')] = value;
        return acc;
    }, {});
}

function translateEventForPhpSpecificEnvironmentVariable(event)
{
    return {
        REDIRECT_STATUS: 200,
        SCRIPT_FILENAME: "index.php",
        REQUEST_URI: event.path
    };
}

function translateEventForCgiEnvironmentVariables(contentLength, event)
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
        SCRIPT_NAME: "index.php",
        SERVER_NAME: event.headers['Host'],
        SERVER_PORT: event.headers['X-Forwarded-Port'],
        SERVER_PROTOCOL: event.protocol,
        SERVER_SOFTWARE: process.env['_HANDLER']
    };
}

function translateEventForEnvironmentVariables(body, event)
{
    const contentLength = body ? body.length : null;

    return Object.assign(
        {},
        process.env,
        translateEventForCgiEnvironmentVariables(contentLength, event),
        translateEventForPhpSpecificEnvironmentVariable(event),
        translateHeadersForPhpHeaderEnvironmentVariables(event));
}

async function handler(event, context)
{
    console.log(event);
    console.log(context);

    const body = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;

    const env = translateEventForEnvironmentVariables(body, event);

    const php = spawnSync(
        '/opt/bin/php-cgi',
        ['-c', 'php.ini'],
        {cwd: process.env.LAMBDA_TASK_ROOT, env: env, input: body});

    if (php.status === 0)
    {
        const response = parseResponse(php.stdout.toString('utf8'));

        return {
            statusCode: response.statusCode || 200,
            headers: response.headers,
            body: response.body,
            isBase64Encoded: false
        };
    }
    else
    {
        throw new Error(php.stderr.toString('utf8'));
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};
