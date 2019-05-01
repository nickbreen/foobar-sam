const path = require('path');

class Resolver
{
    constructor(dirIndex)
    {
        this.dirIndex = dirIndex;
        this.defaultScriptName = path.resolve("/", this.dirIndex);
        // https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info
        this.cgiRegExp = /^(.+\.php)(\/.*)?$/;
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

module.exports = exports = {Resolver};