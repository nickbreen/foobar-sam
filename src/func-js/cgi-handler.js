const {spawnSync} = require('child_process');
const {parseResponse} = require('http-string-parser');
const MIMEType = require('whatwg-mimetype');
const {Handler} = require('./handler');
const AWSXRay = require("aws-xray-sdk");

function findHeader(headers, headerName)
{
    return Object.entries(headers)
        .find(([header]) => header.toLowerCase() === headerName.toLowerCase()) || [];
}

class CgiHandler extends Handler
{
    constructor(memLimit, remainingTimeInMillis)
    {
        super(memLimit, remainingTimeInMillis);
        this.cmd = '/opt/bin/php-cgi';
        this.args = [
//            '-c', '/opt/etc/php.ini',
            '-d', 'memory_limit=' + (this.memLimit / 2) + 'M',
            '-d', 'max_execution_time=' + Math.trunc(this.maxTime / 1000 - 5),
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
            '-d', 'display_errors=1',
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
        const opts = Object.assign(
            {},
            this.opts,
            {
                env: Object.assign({}, process.env, request.env),
                encoding: request.encoding,
                input: request.body
            });

        AWSXRay.captureFunc('handle', (segment) =>
        {
            segment.addMetadata('opts', opts);
        });

        return new Promise((resolve, reject) =>
        {

            AWSXRay.captureFunc('handle/promise', (segment) =>
            {
                const php = spawnSync(this.cmd, this.args, opts);

                segment.addAnnotation('php/status', php.status);
                segment.addMetadata('php', php);

                if (php.status === 0)
                {
                    const response = parseResponse(php.stdout.toString());

                    const [, contentType] = findHeader(response.headers, 'content-type');
                    const mimeType = MIMEType.parse(contentType);

                    const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(response.body, mimeType);

                    segment.addMetadata('response', response);
                    segment.addMetadata('mimeType', mimeType);
                    segment.addMetadata('base64Encoded', base64Encoded);
                    segment.addMetadata('body', responseBody);

                    resolve({
                        statusCode: response.statusCode || 200,
                        headers: response.headers,
                        body: responseBody,
                        isBase64Encoded: base64Encoded
                    });
                }
                else
                {
                    reject(php.status);
                }
            });

        });
    }
}

module.exports = exports = {CgiHandler};