const fs = require("fs");
const {Handler} = require("./handler");
const {createHash} = require('crypto');

const dateToString = Date.prototype.toUTCString ? Date.prototype.toUTCString : Date.prototype.toGMTString;

class FileHandler extends Handler
{
    constructor(memLimit, remainingTimeInMillis)
    {
        super(memLimit, remainingTimeInMillis);
    }

    handle(request)
    {
        return new Promise((resolve, reject) =>
        {
            try
            {
                const data = fs.readFileSync(request.filePath, {});
                const lastModified = dateToString.call(new Date(fs.statSync(request.filePath).mtimeMs));
                const hash = createHash('md5');
                hash.update(data);
                const digest = hash.digest('hex');

                const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(data, request.mimeType);
                resolve({
                    statusCode: 200,
                    headers: {
                        'Last-Modified': lastModified,
                        'Content-Type': request.mimeType.toString(),
                        'ETag': digest,
                        'Content-MD5': digest
                    },
                    body: responseBody,
                    isBase64Encoded: base64Encoded
                });
            }
            catch (e)
            {
                reject(e);
            }
        });
    }
}

module.exports = exports = {FileHandler};