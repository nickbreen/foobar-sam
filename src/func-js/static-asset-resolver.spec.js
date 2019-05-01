const {expect} = require('chai');

const {StaticAssetResolver} = require('./static-asset-resolver');

describe('static-asset-resolver.js', function ()
{
    describe('StaticAssetResolver', function ()
    {
        const resolver = new StaticAssetResolver('index.php', '/docroot');

        describe('Static files characterisation', function ()
        {
            const staticFiles = [
                {
                    args: ['/wp-content/uploads/2001/01/01/image.jpg'],
                    result: '/docroot/wp-content/uploads/2001/01/01/image.jpg'
                },
                {
                    args: ['/index.php/wp-content/uploads/2001/01/01/image.jpg'],
                    result: undefined
                },
                {
                    args: ['/index.php/wp-content/uploads/2001/01/01/image.jpg/index.php'],
                    result: undefined
                }
            ];

            staticFiles.forEach(({args, result}) => {
                it('should do what?', () => {
                    // noinspection BadExpressionStatementJS
                    expect(resolver.resolveStaticAsset(...args)).to.eql(result);
                });
            });
        });
    });
});
