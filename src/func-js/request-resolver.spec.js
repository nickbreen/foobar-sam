const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");
const fs = require('fs');
const path = require('path');

const {RequestResolver, BadRequest, CgiRequest, FileRequest} = require('./request-resolver');

chai.use(chaiAsPromised);
chai.should();

/* Ref: https://tools.ietf.org/html/rfc3875

3.2.  Script Selection

   The server determines which CGI is script to be executed based on a
   generic-form URI supplied by the client.  This URI includes a
   hierarchical path with components separated by "/".  For any
   particular request, the server will identify all or a leading part of
   this path with an individual script, thus placing the script at a
   particular point in the path hierarchy.  The remainder of the path,
   if any, is a resource or sub-resource identifier to be interpreted by
   the script.

3.3.  The Script-URI

      script-URI = <scheme> "://" <server-name> ":" <server-port>
                   <script-path> <extra-path> "?" <query-string>

4.1.  Request Meta-Variables

         meta-variable-name = "AUTH_TYPE" | "CONTENT_LENGTH" |
                              "CONTENT_TYPE" | "GATEWAY_INTERFACE" |
                              "PATH_INFO" | "PATH_TRANSLATED" |
                              "QUERY_STRING" | "REMOTE_ADDR" |
                              "REMOTE_HOST" | "REMOTE_IDENT" |
                              "REMOTE_USER" | "REQUEST_METHOD" |
                              "SCRIPT_NAME" | "SERVER_NAME" |
                              "SERVER_PORT" | "SERVER_PROTOCOL" |
                              "SERVER_SOFTWARE" | scheme |
                              protocol-var-name | extension-var-name
         protocol-var-name  = ( protocol | scheme ) "_" var-name

   This specification does not distinguish between zero-length (NULL)
   values and missing values.


4.1.5.  PATH_INFO

   The PATH_INFO variable specifies a path to be interpreted by the CGI
   script.  It identifies the resource or sub-resource to be returned by
   the CGI script, and is derived from the portion of the URI path
   hierarchy following the part that identifies the script itself.
   Unlike a URI path, the PATH_INFO is not URL-encoded, and cannot
   contain path-segment parameters.  A PATH_INFO of "/" represents a
   single void path segment.

      PATH_INFO = "" | ( "/" path )
      path      = lsegment *( "/" lsegment )

4.1.6.  PATH_TRANSLATED

   The PATH_TRANSLATED variable is derived by taking the PATH_INFO
   value, parsing it as a local URI in its own right, and performing any
   virtual-to-physical translation appropriate to map it onto the
   server's document repository structure.  The set of characters
   permitted in the result is system-defined.

4.1.13.  SCRIPT_NAME

   The SCRIPT_NAME variable MUST be set to a URI path (not URL-encoded)
   which could identify the CGI script (rather than the script's
   output).  The syntax is the same as for PATH_INFO (section 4.1.5)

      SCRIPT_NAME = "" | ( "/" path )

   The leading "/" is not part of the path.  It is optional if the path
   is NULL; however, the variable MUST still be set in that case.

   The SCRIPT_NAME string forms some leading part of the path component
   of the Script-URI derived in some implementation-defined manner.  No
   PATH_INFO segment (see section 4.1.5) is included in the SCRIPT_NAME
   value.

 */

/* Ref: https://www.php.net/manual/en/reserved.variables.server.php

'REQUEST_URI'
    The URI which was given in order to access this page; for instance, '/index.html'.

'SCRIPT_FILENAME'
    The absolute pathname of the currently executing script.


 */

describe('RequestResolver', function ()
{
    const docRoot = fs.mkdtempSync("/tmp/");
    fs.closeSync(fs.openSync(path.resolve(docRoot, 'index.php'), 'w'));
    fs.closeSync(fs.openSync(path.resolve(docRoot, 'index.txt'), 'w'));
    fs.closeSync(fs.openSync(path.resolve(docRoot, 'index.jpg'), 'w'));
    fs.closeSync(fs.openSync(path.resolve(docRoot, 'index.html'), 'w'));
    fs.closeSync(fs.openSync(path.resolve(docRoot, 'index.pdf'), 'w'));

    const resolver = new RequestResolver(docRoot, 'index.php');

    describe('should resolve CgiRequests', function ()
    {
        const cases = [
            {
                args: ['/'],
                expected: new CgiRequest('/index.php', undefined, '/docroot/index.php', undefined, '/')
            },
            {
                args: ['/index.php'],
                expected: new CgiRequest('/index.php', undefined, '/docroot/index.php', undefined, '/index.php')
            },
            {
                args: ['/wp-admin/index.php'],
                expected: new CgiRequest('/wp-admin/index.php', undefined, '/docroot/wp-admin/index.php', undefined, '/wp-admin/index.php')
            },
            {
                args: ['/wp-admin/test.php'],
                expected: new CgiRequest('/wp-admin/test.php', undefined, '/docroot/wp-admin/test.php', undefined, '/wp-admin/test.php')
            },
            {
                args: ['/wp-admin/'],
                expected: new CgiRequest('/wp-admin/index.php', undefined, '/docroot/wp-admin/index.php', undefined, '/wp-admin/')
            },
            {
                args: ['/virtual-file'],
                expected: new CgiRequest('/index.php', '/virtual-file', '/docroot/index.php', '/docroot/virtual-file', '/virtual-file')
            },
            {
                args: ['/virtual-dir/virtual-file'],
                expected: new CgiRequest('/index.php', '/virtual-dir/virtual-file', '/docroot/index.php', '/docroot/virtual-dir/virtual-file', '/virtual-dir/virtual-file')
            },
            {
                args: ['/wp-admin/index.php/virtual-dir/virtual-file'],
                expected: new CgiRequest('/wp-admin/index.php', '/virtual-dir/virtual-file', '/docroot/wp-admin/index.php', '/docroot/virtual-dir/virtual-file', '/wp-admin/index.php/virtual-dir/virtual-file')
            },
            {
                args: ['/wp-admin/test.php/virtual-dir/virtual-file'],
                expected: new CgiRequest('/wp-admin/test.php', '/virtual-dir/virtual-file', '/docroot/wp-admin/test.php', '/docroot/virtual-dir/virtual-file', '/wp-admin/test.php/virtual-dir/virtual-file')
            },
            {
                args: ['/index.php/wp-content/uploads/2001/01/01/image.jpg/index.php'],
                expected: new CgiRequest('/index.php/wp-content/uploads/2001/01/01/image.jpg/index.php', undefined, '/docroot/index.php/wp-content/uploads/2001/01/01/image.jpg/index.php', undefined, '/index.php/wp-content/uploads/2001/01/01/image.jpg/index.php')
            }
        ];

        cases.forEach(({args, expected}) =>
        {
            it(JSON.stringify(args) + ' => ' + JSON.stringify(expected), () =>
            {
                resolver.resolveRequest(...args).should.eventually.eql(expected);
            });
        });
    });

    describe('should resolve FileRequests', function ()
    {
        const staticFiles = [
            {
                args: ['/wp-content/uploads/2001/01/01/image.jpg'],
                expected: new FileRequest('/docroot/wp-content/uploads/2001/01/01/image.jpg', "image/jpeg")
            },
            {
                args: ['/wp-content/uploads/2001/01/01/document.pdf'],
                expected: new FileRequest('/docroot/wp-content/uploads/2001/01/01/document.pdf', "application/pdf")
            },
            {
                args: ['/wp-content/uploads/2001/01/01/json.json'],
                expected: new FileRequest('/docroot/wp-content/uploads/2001/01/01/json.json', "application/json")
            },
        ];

        staticFiles.forEach(({args, expected}) =>
        {
            it(JSON.stringify(args) + ' => ' + JSON.stringify(expected), () =>
            {
                // noinspection BadExpressionStatementJS
                resolver.resolveRequest(...args).should.eventually.eql(expected);
            });
        });
    });

    describe('should throw on bad paths', function ()
    {
        const badPaths = [
            "../../etc/passwd",
            "/index.php/../etc/passwd"
        ];
        badPaths.forEach((badPath) =>
        {
            it('bad path: ' + JSON.stringify(badPath), () =>
            {
                (() => resolver.resolveRequest(badPath)).should.throw(BadRequest);
            });
        });

    });
});
