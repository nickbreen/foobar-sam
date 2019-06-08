
# Prerequisites

- make
- [aws sam cli][] & [aws cli][] 
- docker
- jq 1.6+ (required for base64 decoding)
- diffutils
- dos2unix
- nodejs 8.10+ & npm

# Usage

...Work in Progress

0. Fork/clone this repository. 

1. **WIP** Edit `src/layer-wp/composer.json` to add the required themes, 
   plugins, and any other libraries. Then update `composer.lock` with 
   `make update`.
   
   Or replace it entirely with your own composer project!
   
2. **WIP** Edit `wp-config.php` to suit.    

3. **WIP** Edit src/sam.yaml to change environment variables and parameters
   to suit your deployment. E.g. specify database host/user/pass/name

4. Test with `make test` to 'integration' test the function and API with 
   a simple script that echos the request body as the response body.  

5. Test with `make int` to 'acceptance' test via AP with the same echo script.

5. Test with `make acc` to 'acceptance' test via API with WordPress.

5. Deploy with `make deploy` and then test with `make til` to 'test in 
   live' via the real API gateway.

# Structure

- CloudFormation template (src/sam.yaml) with SAM transform
  - lambda function, nodejs 8.10 (src/func-js)
    
    handles lambda events and hands off to PHP [CGI 1.1]
    
  - lambda layer, PHP 7.3.4 runtime CLI & CGI (src/layer-php)
  
    built based on [img2lambda example]
    
  - lambda layer, composer managed WordPress app (src/layer-wp)
  
    built based on [john bloch] (what about [roots.io][]?)

# References

## PHP
- [Required PHP extensions][]
- [Laravel via CGI][]
- [CGI 1.1][]
- [img2lambda example][]

## SAM
- [AWS Serverless Application Model (SAM)][]
- [SAM 2016-10-31][]
- [sam local invoke][]

## WP

- [Giving WordPress Its Own Directory][]
- [Moving wp-content folder][]
- [john bloch][] / [roots.io][]

## Node + CGI

Packages:

- [node-phpcgi][]
- [cgi][]
- [gateway][]

[node-phpcgi]: https://www.npmjs.com/package/node-phpcgi
[cgi]: https://www.npmjs.com/package/cgi
[gateway]: https://www.npmjs.com/package/gateway

## Other 

- [LambCI][]
- [LambCI Docker][]

# TODO 

- PHPUnit with wp-content/vendor/bin/phpunit



[aws cli]: https://github.com/aws/aws-cli
[aws sam cli]: https://github.com/awslabs/aws-sam-cli
[aws lambda]: https://aws.amazon.com/blogs/compute/upcoming-updates-to-the-aws-lambda-execution-environment/

[Required PHP extensions]: https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions
[Laravel via CGI]: https://cwhite.me/hosting-a-laravel-application-on-aws-lambda/
[CGI 1.1]: https://tools.ietf.org/html/rfc3875
[img2lambda example]: https://github.com/awslabs/aws-lambda-container-image-converter/blob/master/example

[AWS Serverless Application Model (SAM)]: https://github.com/awslabs/serverless-application-model
[SAM 2016-10-31]: https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md
[sam local invoke]: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-cli-command-reference-sam-local-invoke.html]

[john bloch]: https://code.johnpbloch.com/category/wordpress/
[roots.io]: https://roots.io/announcing-the-roots-wordpress-composer-package/
[Giving WordPress Its Own Directory]: https://codex.wordpress.org/Giving_WordPress_Its_Own_Directory
[Moving wp-content folder]: https://codex.wordpress.org/Editing_wp-config.php#Moving_wp-content_folder

[LambCI]: https://github.com/lambci/lambci#php
[LambCI Docker]: https://github.com/lambci/docker-lambda