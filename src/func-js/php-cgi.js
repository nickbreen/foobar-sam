const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');
const fs = require('fs');
const net = require('net');

function findHeader(headers, headerName)
{
    return Object.entries(headers)
        .find(([header]) => header.toLowerCase() === headerName.toLowerCase()) || [];
}

function base64EncodeBodyIfRequired(body, mimeType)
{
    if (!body)
    {
        return {base64Encoded: false, responseBody: null};
    }
    const base64Encoded = mimeType.type !== 'text';
    const charset = mimeType && mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : 'utf8';
    const responseBody = base64Encoded && body ?
        Buffer.from(body, charset).toString('base64') :
        body;
    return {base64Encoded, responseBody};
}

function base64DecodeBodyIfRequired(event, mimeType)
{
    if (event.body)
    {
        const charset = mimeType && mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : 'utf8';
        const encoding = event.isBase64Encoded ? 'base64' : charset;
        return Buffer.from(event.body, encoding);
    }
}

function extractBodyAndEnvironmentVariablesFromEvent(event)
{
    const {script, pathTranslated} = translatePath(event);

    const [, requestContentType] = findHeader(event.headers, 'content-type');
    const requestMimeType = MIMEType.parse(requestContentType);

    const requestBody = base64DecodeBodyIfRequired(event, requestMimeType);
    const contentLength = requestBody ? requestBody.length : null;
    const env = Object.assign(
        {},
        process.env,
        {
            CONTENT_LENGTH: contentLength,
            CONTENT_TYPE: event.headers['Content-Type'] || 'application/octet-stream',
            GATEWAY_INTERFACE: '1.1',
            PATH_INFO: event.path,
            PATH_TRANSLATED: pathTranslated,
            QUERY_STRING: querystring.stringify(event.queryStringParameters),
            REMOTE_ADDR: event.requestContext.identity.sourceIp,
            REMOTE_HOST: event.requestContext.identity.sourceIp,
            REMOTE_IDENT: null,
            REMOTE_USER: null,
            REQUEST_METHOD: event.httpMethod,
            SCRIPT_NAME: script,
            SERVER_NAME: event.headers['Host'],
            SERVER_PORT: event.headers['X-Forwarded-Port'],
            SERVER_PROTOCOL: event.headers['X-Forwarded-Proto'],
            SERVER_SOFTWARE: process.env['_HANDLER']
        },
        {
            // REDIRECT_STATUS: 200, // required if cgi.force_redirect=1
            SCRIPT_FILENAME: script,
            REQUEST_URI: event.path
        },
        Object.entries(event.headers).reduce((acc, [header, value]) =>
        {
            acc['HTTP_' + header.toUpperCase().replace(/-/g, '_')] = value;
            return acc;
        }, {}));

    return {requestBody, env};
}

const roots = [process.env.LAMBDA_TASK_ROOT, "/opt"];
const scriptMod = fs.constants.R_OK | fs.constants.X_OK
function translatePath(event)
{
    const index = process.env.SCRIPT;
    // TODO translate PATH into PATH_TRANSLATED
    //  if it's a dir:
    //      recurse ${PATH}/${index} # catches .../ => .../${index}
    //  if it's a file:
    //      if php and readable (and executable?) then cgi # catches ./${index}/ => CGI
    //      if not php and readable then serve it # catches ./some.gif => served
    //      else 403
    //  else /${index}/${PATH_INFO} => CGI
    //  !! but does not handle direct requests for .../some.php/${PATH_INFO} should it?
    //  find out how Apache HTTPd does it!!

    const script = index;
    fs.accessSync(script, fs.constants.R_OK);
    const pathTranslated = event.path;
    return {script, pathTranslated};
}

async function handler(event, context)
{
    const {requestBody, env} = extractBodyAndEnvironmentVariablesFromEvent(event);

    const args = [
        '-d', 'php.ini',
        '-d', 'memory_limit=' + context.memoryLimitInMB + 'M',
        '-d', 'max_execution_time=' + Math.trunc(context.getRemainingTimeInMillis() / 1000 - 5),
        '-d', 'default_mimetype=application/octet-stream',
        '-d', 'default_charset=UTF-8',
        '-d', 'upload_max_filesize=2M',
        '-d', 'post_max_size=8M',
        '-d', 'cgi.discard_path=1',
        '-d', 'error_log=/dev/stderr',
        '-d', 'cgi.rfc2616_headers=1',
        '-d', 'cgi.force_redirect=0',
        '-d', 'session.save_handler', // unset
        '-d', 'opcache.enable=1',
        '-d', 'enable_post_data_reading=0' // this will probably break WordPress
    ];
    const opts = {
        cwd: process.env.LAMBDA_TASK_ROOT,
        env: env,
        // encoding: 'utf8',
        input: requestBody,
        maxBuffer: 8 * 1024 ** 2, // 8M
        stdio: ['pipe', 'pipe', 'inherit']
    };

    const php = spawnSync('/opt/bin/php-cgi', args, opts); // TODO async

    if (php.status === 0)
    {
        const cgiResponse = php.stdout.toString();

        const httpResponse = parseResponse(cgiResponse);

        const [, responseContentType] = findHeader(httpResponse.headers, 'content-type');

        const responseMimeType = MIMEType.parse(responseContentType);

        console.assert(responseMimeType);

        const {base64Encoded, responseBody} = base64EncodeBodyIfRequired(httpResponse.body, responseMimeType);

        return {
            statusCode: httpResponse.statusCode || 200,
            headers: httpResponse.headers,
            body: responseBody,
            isBase64Encoded: base64Encoded
        };
    }
    else
    {
        throw new Error(php.error);
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};
