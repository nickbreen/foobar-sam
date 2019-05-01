const path = require('path');
const fs = require('fs');
const {Resolver} = require("./resolver");

class StaticAssetResolver extends Resolver
{
    constructor(dirIndex, docRoot)
    {
        super(dirIndex);
        this.mod = fs.constants.R_OK | fs.constants.X_OK;
        this.docRoot = docRoot;
    }

    resolveStaticAsset(requestPath)
    {
        const [scriptName, pathInfo] = this.parseScriptAndPathInfo(requestPath) || [, requestPath];
        return pathInfo && !scriptName ? path.resolve(this.docRoot, pathInfo.slice(1)) : undefined;
    }
}

module.exports = exports = {StaticAssetResolver};