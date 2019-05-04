const fs = require("fs");
const path = require("path");
const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");

const {FileRequest} = require('./file-request');

chai.use(chaiAsPromised);
chai.should();

function touch(dir, ...files)
{
    return files.map((file) => fs.closeSync(fs.openSync(path.resolve(dir, file), 'w')));
}

describe("FileRequest", () =>
{
    const docRoot = fs.mkdtempSync("/tmp/");
    touch(docRoot, 'file.css', 'file.js', 'file.json', 'file.txt', 'file.jpg', 'file.html', 'file.pdf');

    const cases = [
        {
            args: [path.resolve(docRoot, 'file.css')],
            expect: {
                filePath: path.resolve(docRoot, 'file.css'),
                mimeType: 'text/css',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.js')],
            expect: {
                filePath: path.resolve(docRoot, 'file.js'),
                mimeType: 'application/javascript',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.json')],
            expect: {
                filePath: path.resolve(docRoot, 'file.json'),
                mimeType: 'application/json',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.txt')],
            expect: {
                filePath: path.resolve(docRoot, 'file.txt'),
                mimeType: 'text/plain',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.jpg')],
            expect: {
                filePath: path.resolve(docRoot, 'file.jpg'),
                mimeType: 'image/jpeg',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.html')],
            expect: {
                filePath: path.resolve(docRoot, 'file.html'),
                mimeType: 'text/html',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'file.pdf')],
            expect: {
                filePath: path.resolve(docRoot, 'file.pdf'),
                mimeType: 'application/pdf',
                exists: true
            }
        },
        {
            args: [path.resolve(docRoot, 'nofile.pdf')],
            expect: {
                filePath: path.resolve(docRoot, 'nofile.pdf'),
                mimeType: 'application/pdf',
                exists: false
            }
        },
    ];

    cases.forEach(({args, expect}) =>
    {
        it(JSON.stringify(args) + ' => ' + JSON.stringify(expect), () =>
        {
            const request = new FileRequest(...args);
            request.filePath.should.eql(expect.filePath);
            request.mimeType.should.eql(expect.mimeType);
            request.exists().should.eventually.satisfy((exists) => exists === expect.exists);
        });
    });
});