const MIMEType = require('whatwg-mimetype');
const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");

const {Handler} = require('./handler');

chai.use(chaiAsPromised);
chai.should();

describe("Handler", () =>
{
    const textMimeType = new MIMEType("text/plain;charset=UTF-8");
    const applicationMimeType = new MIMEType("application/octet-stream");

    const utf8String = "Tēnā koe";
    const utf8Buffer = Buffer.from(utf8String, 'utf-8');
    const base64String = "VMSTbsSBIGtvZQ==";

    describe('base64EncodeBodyIfRequired', () => {

        it("should encode text/plain utf-8 buffer to utf-8 string", () =>
        {
            const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(utf8Buffer, textMimeType);
            // noinspection BadExpressionStatementJS
            base64Encoded.should.be.a("boolean").and.be.false;
            responseBody.should.be.a('string').and.eql(utf8String);
        });

        it("should encode text/plain utf-8 string to utf-8 string", () =>
        {
            const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(utf8String, textMimeType);
            // noinspection BadExpressionStatementJS
            base64Encoded.should.be.a("boolean").and.be.false;
            responseBody.should.be.a('string').and.eql(utf8String);
        });

        it("should encode application/octet-stream utf-8 string to base64 buffer", () =>
        {
            const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(utf8String, applicationMimeType);
            // noinspection BadExpressionStatementJS
            base64Encoded.should.be.a("boolean").and.be.true;
            responseBody.should.be.a('string').and.eql(base64String);
        });

        it("should encode application/octet-stream utf-8 buffer to base64 buffer", () =>
        {
            const {base64Encoded, responseBody} = Handler.base64EncodeBodyIfRequired(utf8Buffer, applicationMimeType);
            // noinspection BadExpressionStatementJS
            base64Encoded.should.be.a("boolean").and.be.true;
            responseBody.should.be.a('string').and.eql(base64String);
        });

    });
});