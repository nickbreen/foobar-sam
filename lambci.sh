#!/bin/sh

set -ueo pipefail

composer_args="--no-interaction"
composer="composer ${composer_args}"

. ~/init/php 7.3.3
${composer} config version $(git describe --abbrev=0)
${composer} install --prefer-dist
${composer} archive
