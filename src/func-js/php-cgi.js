const {RequestResolver} = require("./request-resolver");
const {CgiHandler} = require('./cgi-handler');

async function handler(event, context)
{
    try
    {
        const requestResolver = new RequestResolver(process.env.DOC_ROOT, process.env.DIR_INDEX);
        const request = await requestResolver.resolveRequest(event);

        switch (request.constructor.name)
        {
            case 'CgiRequest':
                new CgiHandler(context).handle(request).then(context.succeed, context.fail);
                break;
            case 'FileRequest':
                context.fail(request);
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
