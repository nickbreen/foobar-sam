const MIMEType = require('whatwg-mimetype');

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
    SCRIPT_NAME: undefined, // TODO
    SERVER_NAME: undefined,
    SERVER_PORT: undefined,
    SERVER_PROTOCOL: 'HTTP/1.1',
    SERVER_SOFTWARE: process.env.AWS_EXECUTION_ENV
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

class CgiRequest
{
    constructor(pathInfo, pathTranslated, requestUri, scriptFileName, scriptName)
    {
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
            this.encoding = mimeType.parameters.get('charset') || 'UFT-8';
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

module.exports = exports = {CgiRequest};
