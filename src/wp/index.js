const AWS = require('aws-sdk');
const http = require('http');
const net = require('net');
const {URL} = require('url');
const querystring = require('querystring');
const {spawn, spawnSync} = require('child_process');

class PHPServer
{
    constructor(php, host, port, workingDirectory, entryPoint = 'index.php')
    {
        this.php = php;
        this.host = host;
        this.port = port;
        this.workingDirectory = workingDirectory;
        this.entryPoint = entryPoint;
        this.ws = null;
    }

    start()
    {
        if (!this.ws)
        {
            const args = ['-S', this.host + ':' + this.port, '-t', this.workingDirectory, this.entryPoint];
            const opts = {};
            console.debug('spawn', this.php, args, opts);
            this.ws = spawn(this.php, args, opts);
            console.debug('spawned', this.ws);
            console.debug('signal', this.ws.signal);
            console.debug('error', this.ws.error);
            this.ws.stdout.on('data', (data) => console.debug('data', data));
            this.ws.stderr.on('data', (data) => console.error('data', data));
            this.ws.on('message', (msg, handle) => console.debug('message', msg, handle));
            this.ws.on('disconnect', () => console.error('disconnect'));
            this.ws.on('error', (err) => console.error('error', err));
            this.ws.on('close', (code, sig) =>
            {
                console.debug('close', code, sig);
                this.ws = null;
            });
            this.ws.on('exit', (code, sig) =>
            {
                console.debug('exit', code, sig);
                this.ws = null;
            });
        }
        return this;
    }
    waitForConnection()
    {
        let connected = false;
        do
        {
            let sock = net.connect(this.port, this.host, () => connected = true);
            console.debug(sock);
        }
        while (!connected);
        return this;
    }
    kill(sig)
    {
        if (this.ws)
        {
            this.ws.kill(sig);
        }
        return this;
    }
}

const ws = new PHPServer('/opt/bin/php', 'localhost', '8080', process.env.LAMBDA_TASK_ROOT);

process.on('SIGHUP', ws.kill);
process.on('SIGINT', ws.kill);
process.on('SIGQUIT', ws.kill);
process.on('SIGTERM', ws.kill);

async function phpHandler(event, context)
{
    const url = new URL(event.path, "http://localhost:8080");
    url.search = querystring.stringify(event.multiValueQueryStringParameters);

    return new Promise((resolve, reject) =>
    {
        ws.start().waitForConnection();
        const request = http.request({
            host: url.hostname,
            port: url.port,
            path: url.pathname + '?' + url.search,
            method: event.httpMethod,
            headers: event.headers,
            timeout: context.getRemainingTimeInMillis()
        }, (response) =>
        {
            console.log(response);
            resolve({
                statusCode: response.statusCode,
                headers: response.headers,
                body: response.body,
                isBase64Encoded: event.isBase64Encoded
            });
        });

        request.on('error', (response) =>
        {
            console.error(response);
            reject({
                statusCode: response.statusCode,
                headers: response.headers,
                body: response.body,
                isBase64Encoded: event.isBase64Encoded
            });
        });

        request.end(event.body);
    });
}

async function handler(event, context)
{
    const url = new URL(event.path, "http://localhost:8080");
    url.search = querystring.stringify(event.multiValueQueryStringParameters);
    return {
        statusCode: 200,
        headers: event.headers,
        body: JSON.stringify({url, event, context, env: process.env}),
        isBase64Encoded: event.isBase64Encoded
    };
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler, phpHandler};
