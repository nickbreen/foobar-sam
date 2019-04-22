const AWS = require('aws-sdk');
const proxy = require('http-proxy');

function startPhpWebServer()
{
    return "localhost:8080";
}

function proxyRequest(ws, event, context)
{
    const {path} = event;
    const {awsRequestId} = context;

    return {
        statusCode: 200,
        headers: {
            "content-type": "application/json"
        },
        body: JSON.stringify({path, awsRequestId}),
        isBase64Encoded: false
    };
}

const ws = startPhpWebServer();

async function handler(event, context)
{
    try
    {
        const response = proxyRequest(ws, event, context);
        console.debug(response);
        return response;
    }
    catch (e)
    {
        throw e;
    }
}

exports.handler = handler;
