class Handler
{
    constructor(memLimit, remainingTimeInMillis)
    {
        this.memLimit = memLimit;
        this.maxTime = remainingTimeInMillis;
    }

    static base64EncodeBodyIfRequired(body, mimeType)
    {
        if (!body)
        {
            return {base64Encoded: false, responseBody: null};
        }
        const base64Encoded = mimeType.type !== 'text';
        const charset = mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : null;
        const encoding = base64Encoded ? 'base64' : charset ? charset : 'utf-8';
        const responseBody = base64Encoded
            ? Buffer.from(body, charset).toString(encoding)
            : body instanceof Buffer
                ? body.toString(encoding)
                : body;
        return {base64Encoded, responseBody};
    }
}

module.exports = exports = {Handler};