const {RequestResolver, CgiRequest, FileRequest} = require("./request-resolver");
const {CgiHandler} = require('./cgi-handler');
const {FileHandler} = require('./file-handler');
const AWSXRay = require("aws-xray-sdk");

function buildHandler(request, context)
{
    switch (request.constructor)
    {
        case CgiRequest:
            return new CgiHandler(context.memoryLimitInMB, context.getRemainingTimeInMillis());
        case FileRequest:
            return new FileHandler(context.memoryLimitInMB, context.getRemainingTimeInMillis());
        default:
            throw new Error("Unknown request type");
    }
}

async function handler(event, context)
{
    try
    {
        AWSXRay.captureFunc('init', (segment) =>
        {
            segment.addMetadata('env', process.env);
            segment.addMetadata('context', context);
            segment.addMetadata('event', event);
        });

        const requestResolver = new RequestResolver(process.env.DOC_ROOT, process.env.DIR_INDEX);
        const request = await requestResolver.resolveRequest(event);

        AWSXRay.captureFunc('request', (segment) => segment.addMetadata('request', request));

        const handler = buildHandler(request, context);

        AWSXRay.captureFunc('handler', (segment) => segment.addMetadata('handler', handler));

        return (await handler.handle(request)); //.then(context.succeed, context.fail);
    }
    catch (e)
    {
        AWSXRay.captureFunc('error', (segment) => segment.addMetadata('error', e));
        // context.fail(e);
    }
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};
