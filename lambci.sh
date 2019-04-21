#!/bin/sh

set -ueo pipefail

composer_args="-vvv --no-interaction"
composer="composer ${composer_args}"

version=$(git describe --abbrev=0)

. ~/init/php 7.3.3
${composer} config version ${version}
${composer} install --prefer-dist
${composer} archive

node ./upload-artifacts.js *-${version}.tar