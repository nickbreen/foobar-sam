#!/bin/bash

set -euo pipefail

yellow='\033[0;33m'
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m' # No Color

declare template
declare stack

: ${template:? root template file for stack]}
: ${stack:? stack name}

export TMPDIR=.

tmp_caps=$(mktemp --suffix ${stack}.caps)
tmp_template=$(mktemp --suffix ${stack}.template)

err()
{
    aws cloudformation describe-stack-events --stack-name $1 |
     jq -r '.stackEvents[] | select(.ResourceStatus == "UPDATE_FAILED" or .ResourceStatus == "CREATE_FAILED") | "\(.Timestamp)\t\(.ResourceStatusReason)"' |
     head -3 >&2
}

trap "err ${stack}" ERR
trap "rm ${tmp_caps} ${tmp_template}" EXIT

echo -ne "${yellow}${stack}${nc}: validating templates: "
for t in $template
do
    err=$(aws cloudformation validate-template --template-body file://${t} --output text 2>&1 | tee -a ${tmp_caps})
    errno=$?
    if test ${errno} -eq 0
    then echo -ne "${green}$t${nc} "
    else echo -e "${red}$t${nc}"; echo ${err}; exit ${errno}
    fi
done && echo
caps="CAPABILITY_IAM $(sed -n '/^CAPABILITIES\s*/{s/CAPABILITIES\s*//; p}' ${tmp_caps} | sort -u | tr $'\n' ' ')"
declare region
declare bucket
aws ${region:+--region $region} cloudformation package \
    --s3-bucket ${bucket:-build.foobar.nz} --template-file ${template} \
    --output-template-file ${tmp_template} ||
    exit $?
aws ${region:+--region $region} cloudformation deploy \
    --template-file ${tmp_template} --stack-name ${stack} \
    ${caps:+--capabilities $caps} ${@:+--parameter-overrides "${@}"} || 
    exit $?
