const {spawnSync} = require('child_process');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');

function findHeader(headers, headerName)
{
    return Object.entries(headers)
        .find(([header]) => header.toLowerCase() === headerName.toLowerCase()) || [];
}

function base64EncodeBodyIfRequired(body, mimeType)
{
    if (!body)
    {
        return {base64Encoded: false, responseBody: body};
    }
    const base64Encoded = mimeType.type !== 'text';
    const charset = mimeType.parameters.has("charset") ? mimeType.parameters.get("charset") : 'utf8';
    const responseBody = base64Encoded ? Buffer.from(body, charset).toString('base64') : body;
    return {base64Encoded, responseBody};
}


class CgiHandler
{
    constructor(context)
    {
        this.cmd = '/opt/bin/php-cgi';
        this.args = [
            '-c', '/opt/etc/php.ini',
            '-d', 'memory_limit=' + (context.memoryLimitInMB / 2) + 'M',
            '-d', 'max_execution_time=' + Math.trunc(context.getRemainingTimeInMillis() / 1000 - 5),
            '-d', 'default_mimetype=application/octet-stream',
            '-d', 'default_charset=UTF-8',
            '-d', 'upload_max_filesize=2M',
            '-d', 'post_max_size=8M',
            '-d', 'cgi.discard_path=1',
            '-d', 'error_log=/dev/stderr',
            '-d', 'cgi.rfc2616_headers=1',
            '-d', 'cgi.force_redirect=0',
            '-d', 'session.save_handler', // unset
            '-d', 'opcache.enable=1',
            '-d', 'enable_post_data_reading=0', // this will probably break WordPress
            '-d', 'auto_prepend_file=' + process.env.LAMBDA_TASK_ROOT + '/buffer.php',
        ];
        this.opts = {
            cwd: process.env.LAMBDA_TASK_ROOT,
            env: undefined,
            encoding: undefined,
            input: undefined,
            maxBuffer: 8 * 1024 ** 2, // 8M
            stdio: ['pipe', 'pipe', 'inherit']
        };
    }

    handle(request)
    {
        return new Promise((resolve, reject) =>
        {
            const opts = Object.assign(
                {},
                this.opts,
                {
                    env: Object.assign({}, process.env, request.env),
                    encoding: request.encoding,
                    input: request.body
                });

            const php = spawnSync(this.cmd, this.args, opts);

            if (php.status === 0)
            {
                const httpResponse = parseResponse(php.stdout.toString());

                const [, responseContentType] = findHeader(httpResponse.headers, 'content-type');

                const responseMimeType = MIMEType.parse(responseContentType);

                const {base64Encoded, responseBody} = base64EncodeBodyIfRequired(httpResponse.body, responseMimeType);

                resolve({
                    statusCode: httpResponse.statusCode || 200,
                    headers: httpResponse.headers,
                    body: responseBody,
                    isBase64Encoded: base64Encoded
                });
            }
            else
            {
                reject(php.status);
            }
        });
    }
}

module.exports = exports = {CgiHandler};