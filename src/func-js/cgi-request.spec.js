const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");

const {CgiRequest} = require('./cgi-request');

chai.use(chaiAsPromised);
chai.should();

describe("CgiRequest", () =>
{
    const cases = [
        {
            args: {
                constructorArgs: [
                    '/path/info',
                    '/docroot/path/translated',
                    '/dir/index.php/path/info',
                    '/docroot/dir/index.php',
                    '/dir/index.php'
                ],
                headers: {
                    'Content-Type': 'text/plain; charset=UTF-8',
                    'Header-With-One-Value': 'Header Value',
                    'Header-With-Two-Values': ['header value 1', 'header value two']
                },
            },
            expect: {
                PATH_INFO: '/path/info',
                PATH_TRANSLATED: '/docroot/path/translated',
                REQUEST_URI: '/dir/index.php/path/info',
                SCRIPT_FILENAME: '/docroot/dir/index.php',
                SCRIPT_NAME: '/dir/index.php',
                CONTENT_TYPE: 'text/plain;charset=UTF-8', // note space has been normalised out
                HTTP_HEADER_WITH_ONE_VALUE: 'Header Value',
                HTTP_HEADER_WITH_TWO_VALUES: 'header value 1, header value two'
            },
            expectNot: {
                HTTP_CONTENT_TYPE: undefined,
                HTTP_CONTENT_LENGTH: undefined,
                HTTP_AUTHORISATION: undefined
            }
        }
    ];

    cases.forEach(({args, expect, expectNot}) =>
    {
        it(JSON.stringify(args) + ' => ' + JSON.stringify(expect), () =>
        {
            const request = new CgiRequest(...args.constructorArgs)
                .contentType(args.headers['Content-Type'])
                .headers(args.headers);

            request.env.should.include(expect);
            request.env.should.not.have.keys(...Object.keys(expectNot));
            request.encoding.should.eql('UTF-8');
        });
    });
});
