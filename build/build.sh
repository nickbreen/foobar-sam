#!/bin/bash

set -ueo pipefail -v

trap 'printenv' EXIT

declare LAMBCI_REPO LAMBCI_BRANCH LAMBCI_BUILD_NUM

composer_args="--no-interaction"
composer="composer ${composer_args}"

version=$(git describe | awk -F- '{ \
	gsub(/^v/, "", $1); \
	if ($2 && $3) \
	{ print $1 "+" $2 "." $3 } \
	else \
	{ print $1} \
	}').b${LAMBCI_BUILD_NUM}

echo Version: ${version}

mkdir -p out

cp --remove-destination --target-directory=out/ composer.json composer.lock
${composer} install --working-dir=out/ --prefer-dist
${composer} config version --working-dir=out/ ${version}
${composer} update --working-dir=out/ --lock
${composer} archive --working-dir=out/ --format=zip
(
    cd build
    npm install
)
#key=artifacts/${LAMBCI_REPO}/${LAMBCI_BRANCH}/${LAMBCI_BUILD_NUM}
#node build/upload-artifacts.js s3 wp.foobar.nz ${key} out/*.zip

name=$(${composer} config name --working-dir=out/ )
node build/upload-artifacts.js layer ${name} out/*.zip
