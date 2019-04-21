#!/bin/bash

set -ueo pipefail

trap 'printenv' ERR

declare BUCKET LAMBCI_REPO LAMBCI_BRANCH LAMBCI_BUILD_NUM

composer_args="--no-interaction"
composer="composer ${composer_args}"

git_version=$(git describe)
git_tag=${git_version%%-*}
git_pre=${git_version#*-}

version="${git_tag#v}${git_pre+-${git_pre/-/.}}${LAMBCI_BUILD_NUM++b${LAMBCI_BUILD_NUM}}"

${composer} config version ${version}
${composer} install --prefer-dist
${composer} archive

(
    cd build
    npm install
)
key=artifacts/${LAMBCI_REPO}/${LAMBCI_BRANCH}/${LAMBCI_BUILD_NUM}
node build/upload-artifacts.js ${BUCKET} ${key} *-${version}.tar
