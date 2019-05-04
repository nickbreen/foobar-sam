const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");

const {FileRequest} = require('./file-request');
const {FileHandler} = require('./file-handler');

chai.use(chaiAsPromised);
chai.should();

describe("FileHandler", () =>
{
    const dir = fs.mkdtempSync("/tmp/");

    const fileThatExists = path.resolve(dir, 'file.txt');

    const fileContent = Buffer.from("Tēnā koe", 'utf-8').toString('utf-8');

    const mtime = Date.UTC(2019, 5-1, 4, 23, 55, 10, 567) / 1000;
    const fd = fs.openSync(fileThatExists, 'w');
    fs.writeSync(fd, fileContent);
    fs.futimesSync(fd, mtime, mtime);
    fs.closeSync(fd);

    const hash = crypto.createHash('md5');
    hash.update(fileContent);
    const digest = hash.digest('hex');

    console.assert(digest === 'a59fad9882bd3704e0665c96fa040626');

    it("should response with file that exists", async () =>
    {
        const handler = new FileHandler(100, 5000);
        const response = await handler.handle(new FileRequest(fileThatExists));

        // noinspection BadExpressionStatementJS
        response.should.exist.and.be.an('object');
        response.headers.should.exist.and.be.an('object');
        response.statusCode.should.eql(200);
        response.headers['Content-Type'].should.exist.and.be.eql("text/plain");
        response.headers['Last-Modified'].should.exist.and.be.eql('Sat, 04 May 2019 23:55:10 GMT');
        response.headers['ETag'].should.exist.and.be.eql('a59fad9882bd3704e0665c96fa040626');
        response.headers['Content-MD5'].should.exist.and.be.eql('a59fad9882bd3704e0665c96fa040626');
        response.body.toString('utf-8').should.eql(fileContent);
        // noinspection BadExpressionStatementJS
        response.isBase64Encoded.should.be.false;
    });

    it("should throw for file that does not exist", () =>
    {
        const handler = new FileHandler(100, 5000);
        const response = handler.handle(new FileRequest('nofile.pdf'));
        // noinspection BadExpressionStatementJS
        response.should.eventually.throw;
    });
});