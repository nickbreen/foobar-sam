const path = require('path');
const querystring = require('querystring');
const {FileRequest} = require("./file-request");
const {CgiRequest} = require("./cgi-request");

// Ref: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info

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

        return new Promise((resolve) =>
        {
            resolve(new FileRequest(pathTranslated));
        })
            .then((fileRequest) => fileRequest.exists())
            .catch(() => new CgiRequest(pathInfo, pathTranslated, requestPath, scriptFileName, scriptName)
                .contentType(event.headers['Content-Type'])
                .headers(event.headers)
                .queryString(querystring.stringify(event.queryStringParameters))
                .entity(event.body, event.isBase64Encoded));
    }

    parseScriptAndPathInfo(requestPath)
    {
        const matches = this.cgiRegExp.exec(requestPath);
        return matches ? matches.slice(1, 3) : undefined;
    }
}

class BadRequest extends Error
{
    constructor(message, code = 400, name = 'Bad Request')
    {
        super();
        this.message = message;
        this.name = name;
        this.code = code;
    }
}

module.exports = exports = {RequestResolver, CgiRequest, FileRequest, BadRequest};