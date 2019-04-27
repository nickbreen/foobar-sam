const {spawnSync} = require('child_process');

async function handler(event, context)
{
    return new Promise((resolve, reject) =>
    {
        const php = spawnSync(
            '/opt/bin/php',
            ['-c', 'php.ini', '-f', 'index.php'],
            {cwd: process.env.LAMBDA_TASK_ROOT, env: process.env, input: event.body});
        if (php.status === 0)
        {
            resolve({
                statusCode: 200,
                headers: [
                    'Content-Type: text/plain'
                ],
                body: php.stdout.toString('utf8'),
                isBase64Encoded: event.isBase64Encoded
            });
        }
        else
        {
            console.error(php.stderr.toString('utf8'));
            reject({
                statusCode: 500,
                headers: [],
                body: null,
                isBase64Encoded: false
            });
        }
    });
}

// noinspection JSUnusedGlobalSymbols
module.exports = exports = {handler};