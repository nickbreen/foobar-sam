#!/bin/bash

set -ueo pipefail

composer_args="--no-interaction"
composer="composer ${composer_args}"

version=$(git describe --abbrev=0)

${composer} config version ${version}
${composer} install --prefer-dist
${composer} archive

declare BUCKET LAMBCI_REPO LAMBCI_BRANCH LAMBCI_BUILD_NUMBER

(
    cd build
    npm install
)
env
key=artifacts/${LAMBCI_REPO}/${LAMBCI_BRANCH}/${LAMBCI_BUILD_NUMBER}
node build/upload-artifacts.js ${BUCKET} ${key} *-${version}.tar
