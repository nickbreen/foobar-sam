#!/bin/sh

set -ueo pipefail

printenv

composer_args="-vvv --no-interaction"
composer="composer ${composer_args}"

version=$(git describe --abbrev=0)

. ~/init/php 7.3.3
${composer} config version ${version}
${composer} install --prefer-dist
${composer} archive


#pip install awscli

#aws s3 cp *-${version}.tar