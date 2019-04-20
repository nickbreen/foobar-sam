#!/bin/node

const AWS = require('aws-sdk');
const fs = require('fs');

const s3 = new AWS.S3();

const bucket = process.env.BUCKET;
const key = "artifacts/" + process.env.LAMBCI_REPO + "/" + process.env.LAMBCI_BRANCH + "/" + process.env.LAMBCI_BUILD_NUM

process.argv.slice(2).forEach(tar => {
    s3.upload({Bucket: bucket, Key: key + "/" + tar, Body: fs.createReadStream(tar)});
});
