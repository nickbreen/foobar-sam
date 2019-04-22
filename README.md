
# CI

Use [LambCI](https://github.com/lambci/lambci#php). 

    make deploy-ci

Then any push to master or a tag will trigger CI.

# Local Build

    make 
    
# Deploy

    make deploy
    
# Test  
    
**TODO**: Use https://github.com/lambci/docker-lambda
**TODO**: PHPUnit with wp-content/vendor/bin/phpunit


# WP

- [Giving WordPress Its Own Directory](https://codex.wordpress.org/Giving_WordPress_Its_Own_Directory)
- [Moving wp-content folder](https://codex.wordpress.org/Editing_wp-config.php#Moving_wp-content_folder)


# PHP

- [Required PHP extensions](https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
- Compile in docker with with [amazonlinux:1-wth-sources](https://hub.docker.com/_/amazonlinux)


# Structure

- Lambda Layers
  - PHP
  - AWS PHP SDK - if using for runtime SSM Parameters
  - WordPress
- Lambda Function
  - wp-config.php
    - use SDK to get SSM Parameter Store parameters at runtime?
    - OR; pull from environment (like in foobar-wp-cf)
  - Environment Variables 
    - pull from environment (like in foobar-wp-cf) at deploy time

