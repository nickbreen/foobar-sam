const {getType} = require('mime/lite');
const MIMEType = require('whatwg-mimetype');
const fs = require('fs');
const path = require('path');

class FileRequest
{
    constructor(filePath, mimeType)
    {
        this.filePath = filePath;
        if (mimeType instanceof MIMEType)
        {
            this.mimeType = mimeType;
        }
        else if (mimeType instanceof String)
        {
            this.mimeType = MIMEType.parse(mimeType);
        }
        else
        {
            this.mimeType = mimeType ? mimeType : new MIMEType(getType(path.parse(filePath).ext));
        }
    }

    exists()
    {
        return new Promise((resolve, reject) =>
        {
            fs.access(this.filePath, fs.constants.R_OK & !fs.constants.X_OK, (err) =>
            {
                if (err)
                {
                    reject(err);
                }
                else
                {
                    resolve(this);
                }
            });
        });
    }
}

module.exports = exports = {FileRequest};