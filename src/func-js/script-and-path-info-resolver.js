const path = require('path');
const {Resolver} = require("./request-resolver");

class BadRequest extends Error
{
    constructor(...props)
    {
        super(...props);
        this.name = "Bad Request";
        this.code = 400;
    }
}

class ScriptAndPathInfoResolver extends Resolver
{
    constructor(dirIndex, docRoot)
    {
        super(dirIndex);
        this.docRoot = docRoot;
    }

    resolveCgiScriptNameAndPathInfo(requestPath)
    {
        // TODO detect actual directories and append "/" if API Gateway still strips them?
        //      E.g. /wp/wp-admin => /wp/wp-admin/
        const [scriptName, pathInfo] = this.parseScriptAndPathInfo(requestPath) || [this.defaultScriptName, requestPath];
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

module.exports = exports = {ScriptAndPathInfoResolver, BadRequest};