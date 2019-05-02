const path = require('path');
const fs = require('fs');
const {getType} = require('mime/lite');

class RequestResolver
{
    constructor(
        docRoot,
        dirIndex,
        defaultScriptName = path.resolve("/", dirIndex),
        fallback = defaultScriptName,
        cgiRegExp = /^(.+\.php)(\/.*)?$/
    )
    {
        this.docRoot = docRoot;
        this.dirIndex = dirIndex;
        this.defaultScriptName = defaultScriptName;
        this.fallback = fallback;
        // https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info
        this.cgiRegExp = cgiRegExp;
    }

    resolveRequest(requestPath)
    {
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
            () => new CgiRequest(scriptName, pathInfo, scriptFileName, pathTranslated, requestPath));
    }

    ifFile(filePath)
    {
        return new Promise((resolve, reject) => {
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
{}

class CgiRequest extends Request
{
    constructor(scriptName, pathInfo, scriptFileName, pathTranslated, requestUri)
    {
        super();
        this.scriptName = scriptName;
        this.pathInfo = pathInfo;
        this.scriptFileName = scriptFileName;
        this.pathTranslated = pathTranslated;
        this.requestUri = requestUri;
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