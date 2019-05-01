const {spawnSync} = require('child_process');
const querystring = require('querystring');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');
const fs = require('fs');
const path = require('path');

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
    const scriptAndPathInfoResolver = new ScriptAndPathInfoResolver(process.env.DOC_ROOT, process.env.DIR_INDEX);

    const scriptAndPathInfo = scriptAndPathInfoResolver.resolveUri(event.path);

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
            SERVER_PROTOCOL: event.requestContext.protocol,
            SERVER_SOFTWARE: process.env['_HANDLER']
        },
        scriptAndPathInfo,
        {
            HTTPS: event.headers['X-Forwarded-Proto'],
        },
        Object.entries(event.headers).reduce((acc, [header, value]) =>
        {
            acc['HTTP_' + header.toUpperCase().replace(/-/g, '_')] = value;
            return acc;
        }, {}));

    return {requestBody, charset, env};
}

class BadRequest extends Error
{
    constructor(...props)
    {
        super(...props);
        this.name = "Bad Request";
        this.code = 400;
    }
}

class ScriptAndPathInfoResolver
{
    constructor(docRoot, dirIndex)
    {
        this.mod = fs.constants.R_OK | fs.constants.X_OK;
        this.docRoot = docRoot;
        this.dirIndex = dirIndex;
        // https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info
        this.pathRegExp = /^(.+\.php)(\/.*)?$/;
    }

    parseScriptAndPathInfo(resolvedPath)
    {
        const matches = this.pathRegExp.exec(resolvedPath);
        return matches ? matches.slice(1, 3) : null;
    }

    resolveUri(requestPath)
    {
        // TODO detect actual directories and append "/" if API Gateway still strips them?
        const requestUri = requestPath.endsWith("/") ? path.resolve(requestPath, this.dirIndex) : requestPath;

        const [scriptName, pathInfo] = this.parseScriptAndPathInfo(requestUri) || [
            path.resolve("/", this.dirIndex),
            requestPath
        ];
        const scriptFileName = scriptName ? path.resolve(this.docRoot, scriptName.slice(1)) : undefined;
        const pathInfoTranslated = pathInfo ? path.resolve(this.docRoot, pathInfo.slice(1)) : undefined;

        if (scriptFileName && !scriptFileName.startsWith(this.docRoot))
        {
            throw new BadRequest(scriptFileName + ' => ' + scriptFileName);
        }

        if (pathInfoTranslated && !pathInfoTranslated.startsWith(this.docRoot))
        {
            throw new BadRequest(pathInfo + ' => ' + pathInfoTranslated);
        }

        return {
            PATH_INFO: pathInfo, // CGI/1.1
            PATH_TRANSLATED: pathInfoTranslated, // CGI/1.1
            SCRIPT_NAME: scriptName, // CGI/1.1
            SCRIPT_FILENAME: scriptFileName, // PHP
            REQUEST_URI: requestPath // PHP
        };
    }
}

async function handler(event, context)
{
    const {requestBody, charset, env} = extractBodyAndEnvironmentVariablesFromEvent(event);

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
        cwd: process.env.DOC_ROOT,
        env: env,
        encoding: charset,
        input: requestBody,
        maxBuffer: 8 * 1024 ** 2, // 8M
        // stdio: ['pipe', 'pipe', 'inherit']
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
        throw new Error(php.stderr.toString());
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler, ScriptAndPathInfoResolver, BadRequest};
