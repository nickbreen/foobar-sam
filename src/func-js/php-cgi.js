const {RequestResolver, CgiRequest, FileRequest} = require("./request-resolver");
const {CgiHandler} = require('./cgi-handler');
const {FileHandler} = require('./file-handler');

async function handler(event, context)
{
    try
    {
        const requestResolver = new RequestResolver(process.env.DOC_ROOT, process.env.DIR_INDEX);
        const request = await requestResolver.resolveRequest(event);

        switch (request.constructor)
        {
            case CgiRequest:
                new CgiHandler(context.memoryLimitInMB, context.getRemainingTimeInMillis())
                    .handle(request).then(context.succeed, context.fail);
                break;
            case FileRequest:
                new FileHandler(context.memoryLimitInMB, context.getRemainingTimeInMillis())
                    .handle(request).then(context.succeed, context.fail);
                break;
            default:
                context.fail("Unknown request type");
        }
    }
    catch (e)
    {
        context.fail(e);
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};
