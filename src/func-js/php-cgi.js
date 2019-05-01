const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');
const {ScriptAndPathInfoResolver, BadRequest} = require('./script-and-path-info-resolver');
const {StaticAssetResolver} = require('./static-asset-resolver');

function findHeader(headers, headerName)
{
    return Object.entries(headers)
        .find(([header]) => header.toLowerCase() === headerName.toLowerCase()) || [];
}

function base64EncodeBodyIfRequired(body, mimeType)
{
    if (!body)
    {
        return {base64Encoded: false, responseBody: body};
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
    if (!event.body)
    {
        return {};
    }
    const charset = mimeType && mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : 'utf8';
    const encoding = event.isBase64Encoded ? 'base64' : charset;
    const requestBody = Buffer.from(event.body, encoding);
    return {requestBody, charset};
}

function extractBodyAndEnvironmentVariablesFromEvent(event)
{
    const requestUri = event.path.endsWith("/") ? path.resolve(event.path, this.dirIndex) : event.path;

    const staticAssetResolver = new StaticAssetResolver(process.env.DIR_INDEX, process.env.DOC_ROOT);

    const maybeStaticFilePath = staticAssetResolver.resolveStaticAsset(requestUri);

    if (maybeStaticFilePath)
    {
        // TODO serve it instead of passing to CGI
    }
    
    const scriptAndPathInfoResolver = new ScriptAndPathInfoResolver(process.env.DIR_INDEX, process.env.DOC_ROOT);

    const scriptAndPathInfo = scriptAndPathInfoResolver.resolveCgiScriptNameAndPathInfo(requestUri);

    const [, requestContentType] = findHeader(event.headers, 'content-type');
    const requestMimeType = MIMEType.parse(requestContentType);

    const {requestBody, charset} = base64DecodeBodyIfRequired(event, requestMimeType);
    const contentLength = requestBody ? requestBody.length : null;
    const env = Object.assign(
        {},
        process.env,
        {
            CONTENT_LENGTH: contentLength,
            CONTENT_TYPE: event.headers['Content-Type'] || 'application/octet-stream',
            GATEWAY_INTERFACE: 'CGI/1.1',
            PATH_INFO: undefined,
            PATH_TRANSLATED: undefined,
            QUERY_STRING: querystring.stringify(event.queryStringParameters),
            REMOTE_ADDR: event.requestContext.identity.sourceIp,
            REMOTE_HOST: event.requestContext.identity.sourceIp,
            REMOTE_IDENT: null,
            REMOTE_USER: null,
            REQUEST_METHOD: event.httpMethod,
            SCRIPT_NAME: undefined,
            SERVER_NAME: event.headers['Host'],
            SERVER_PORT: event.headers['X-Forwarded-Port'],
            SERVER_PROTOCOL: event.requestContext.protocol || 'HTTP/1.1',
            SERVER_SOFTWARE: process.env['_HANDLER']
        },
        scriptAndPathInfo,
        {
            HTTPS: event.headers['X-Forwarded-Proto'] === 'https' ? 1 : undefined,  // PHP
        },
        Object.entries(event.headers).reduce((acc, [header, value]) =>
        {
            acc['HTTP_' + header.toUpperCase().replace(/-/g, '_')] = value;
            return acc;
        }, {}));

    return {requestBody, charset, env};
}

function handler(event, context)
{
    const {requestBody, charset, env} = extractBodyAndEnvironmentVariablesFromEvent(event);

    const args = [
        '-c', '/opt/etc/php.ini',
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
        cwd: process.env.DOC_ROOT,
        env: env,
        encoding: charset,
        input: requestBody,
        maxBuffer: 8 * 1024 ** 2, // 8M
    };

    const php = spawnSync('/opt/bin/php-cgi', args, opts); // TODO async

    const stderr = php.stderr.toString();
    console.error(stderr);

    if (php.status === 0)
    {
        const cgiResponse = php.stdout.toString();

        const httpResponse = parseResponse(cgiResponse);

        const [, responseContentType] = findHeader(httpResponse.headers, 'content-type');

        const responseMimeType = MIMEType.parse(responseContentType);

        console.assert(responseMimeType);

        const {base64Encoded, responseBody} = base64EncodeBodyIfRequired(httpResponse.body, responseMimeType);

        context.succeed({
            statusCode: httpResponse.statusCode || 200,
            headers: httpResponse.headers,
            body: responseBody,
            isBase64Encoded: base64Encoded
        });
    }
    else
    {
        context.fail(stderr);
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler, ScriptAndPathInfoResolver, BadRequest};
