const path = require('path');
const fs = require('fs');
const {getType} = require('mime/lite');
const MIMEType = require('whatwg-mimetype');
const querystring = require('querystring');

class RequestResolver
{
    constructor(
        docRoot,
        dirIndex,
        fallback = path.resolve("/", dirIndex),
        cgiRegExp = /^(.+\.php)(\/.*)?$/
    )
    {
        this.docRoot = docRoot;
        this.dirIndex = dirIndex;
        this.fallback = fallback;
        // https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info
        this.cgiRegExp = cgiRegExp;
    }

    resolveRequest(event)
    {
        const requestPath = event.path.endsWith("/") ? path.resolve(event.path, this.dirIndex) : event.path;
        const [scriptName, pathInfo] = this.parseScriptAndPathInfo(requestPath) || [this.fallback, requestPath];

        const scriptFileName = scriptName ? path.resolve(this.docRoot, scriptName.slice(1)) : undefined;
        const pathTranslated = pathInfo ? path.resolve(this.docRoot, pathInfo.slice(1)) : undefined;

        if (scriptFileName && !scriptFileName.startsWith(this.docRoot))
        {
            throw new BadRequest(scriptFileName + ' => ' + scriptFileName);
        }

        if (pathTranslated && !pathTranslated.startsWith(this.docRoot))
        {
            throw new BadRequest(pathInfo + ' => ' + pathTranslated);
        }

        return this.ifFile(pathInfo).then(
            ({filePath, mimeType}) => new FileRequest(filePath, mimeType),
            () => new CgiRequest(pathInfo, pathTranslated, requestPath, scriptFileName, scriptName)
                .contentType(event.headers['Content-Type'])
                .headers(event.headers)
                .queryString(querystring.stringify(event.queryStringParameters))
                .entity(event.body, event.isBase64Encoded));
    }

    ifFile(filePath)
    {
        return new Promise((resolve, reject) =>
        {
            fs.access(filePath, fs.constants.R_OK, (err) =>
            {
                if (err)
                {
                    reject(err);
                }
                else
                {
                    const parsedPath = path.parse(filePath);
                    const mimeType = getType(parsedPath.ext);
                    resolve({filePath, mimeType});
                }
            });
        });
    }

    resolveDirectoryIndexIfRequired(requestPath)
    {
        return requestPath.endsWith("/") ? path.resolve(requestPath, this.dirIndex) : requestPath;
    }

    parseScriptAndPathInfo(requestPath)
    {
        const requestUri = this.resolveDirectoryIndexIfRequired(requestPath);

        const matches = this.cgiRegExp.exec(requestUri);
        return matches ? matches.slice(1, 3) : null;
    }
}

class Request
{
}

const defaultCgiVars = {
    AUTH_TYPE: undefined,
    CONTENT_LENGTH: 0,
    CONTENT_TYPE: 'application/octet-stream',
    GATEWAY_INTERFACE: 'CGI/1.1',
    PATH_INFO: undefined,
    PATH_TRANSLATED: undefined,
    QUERY_STRING: undefined,
    REMOTE_ADDR: undefined,
    REMOTE_HOST: undefined,
    REMOTE_IDENT: undefined,
    REMOTE_USER: undefined,
    REQUEST_METHOD: undefined,
    SCRIPT_NAME: undefined,
    SERVER_NAME: undefined,
    SERVER_PORT: undefined,
    SERVER_PROTOCOL: 'HTTP/1.1',
    SERVER_SOFTWARE: undefined
};

// RFC 3875 4.1.18.  Protocol-Specific Meta-Variables
function cgify(header)
{
    return 'HTTP_' + header.toUpperCase().replace(/-/g, '_');
}

function cgiHeaderFilter([header,])
{
    const cgiHeadersToFilter = {
        'content-type': true,
        'content-length': true,
        'authorisation': true
    };
    return ! cgiHeadersToFilter[header.toLowerCase()];
}


class CgiRequest extends Request
{
    constructor(pathInfo, pathTranslated, requestUri, scriptFileName, scriptName)
    {
        super();
        this.env = Object.assign({}, defaultCgiVars);
        this.env.PATH_INFO = pathInfo;
        this.env.PATH_TRANSLATED = pathTranslated;
        this.env.REQUEST_URI = requestUri;
        this.env.SCRIPT_FILENAME = scriptFileName;
        this.env.SCRIPT_NAME = scriptName;
    }

    contentType(contentType)
    {
        if (contentType)
        {
            const mimeType = MIMEType.parse(contentType);
            this.env.CONTENT_TYPE = mimeType.toString();
            this.encoding = mimeType.encoding;
        }
        return this;
    }

    headers(headers)
    {
        Object.entries(headers)
            .filter(cgiHeaderFilter)
            .forEach(([header, values]) =>
                this.env[cgify(header)] = values instanceof Array ? values.join(", ") : values);
        return this;
    }

    queryString(queryString)
    {
        this.env.QUERY_STRING = queryString;
        return this;
    }

    entity(body, isBase64Encoded)
    {
        if (body)
        {
            this.body = Buffer.from(body, isBase64Encoded ? 'base64' : this.encoding);
            this.env.CONTENT_LENGTH = Buffer.byteLength(this.body,  this.encoding);
        }
        return this;
    }
}

class FileRequest extends Request
{
    constructor(filePath, mimeType)
    {
        super();
        this.filePath = filePath;
        this.mimeType = mimeType;
    }
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

module.exports = exports = {RequestResolver, Request, CgiRequest, FileRequest, BadRequest};