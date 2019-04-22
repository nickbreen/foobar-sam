const AWS = require('aws-sdk');
const fs = require('fs');
const program = require('commander');

const EX_GENERAL = 1, EX_NOINPUT = 66, EX_UNAVAILABLE = 69;

class UploadArtifacts
{

    constructor(s3)
    {
        this.s3 = s3;
    }

    async uploadArtifacts(bucket, prefix, artifacts)
    {

        const uploads = artifacts.map(artifact => this.s3.upload(
            {
                Bucket: bucket,
                Key: prefix + "/" + artifact,
                Body: fs.createReadStream(artifact)
            }).promise()
        );

        try
        {
            return await Promise.all(uploads);
        }
        catch (e)
        {
            throw e;
        }
    }
}

class PublishLayer
{
    lambda;
    constructor(lambda)
    {
        this.lambda = lambda;
    }

    async publishLayer(layerName, zip)
    {
        return lambda.publishLayerVersion(
            {
                LayerName: layerName,
                ZipFile: fs.createReadStream(zip)
            }).promise();
    }
}

module.exports = exports = UploadArtifacts;

if (require.main === module)
{
    program
        .command('layer <name> <zip>')
        .action((name, zip) =>
        {
            new PublishLayer(new AWS.Lambda())
                .publishLayer(name, zip)
                .catch(e =>
                {
                    conole.error(e);
                    process.exit(EX_GENERAL);
                })
                .then(r =>
                {
                    console.debug(r);
                })
        })
        .command('s3 <bucket> <prefix> <artifacts...>')
        .action((bucket, prefix, artifacts) =>
        {
            new UploadArtifacts(new AWS.S3())
                .uploadArtifacts(bucket, prefix, artifacts)
                .catch(e =>
                {
                    console.error(e);
                    if (e.code === 'NOENT')
                    {
                        process.exit(EX_NOINPUT);
                    }
                    else if (e.code === 'NoSuchBucket')
                    {
                        process.exit(EX_UNAVAILABLE);
                    }
                    process.exit(EX_GENERAL)
                })
                .then(r =>
                {
                    console.debug(r);
                });
        }).parse(process.argv);
}