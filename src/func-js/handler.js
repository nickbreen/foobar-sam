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
            return {base64Encoded: false, responseBody: body};
        }
        const base64Encoded = mimeType.type !== 'text';
        const charset = mimeType.parameters && mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : 'utf8';
        const responseBody = base64Encoded ? Buffer.from(body, charset).toString('base64') : body;
        return {base64Encoded, responseBody};
    }
}


module.exports = exports = {Handler};