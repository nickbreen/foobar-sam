#!/usr/bin/env bash

set -euo pipefail

declare OPT host=localhost out port=3000 project src template url

trap 'pkill sam' ERR

while getopts "h:o:P:p:s:t:u:" OPT
do
    case ${OPT} in
    h) host=${OPTARG} ;;
    o) out=${OPTARG} ;;
    P) project=${OPTARG} ;;
    p) port=${OPTARG} ;;
    s) src=${OPTARG} ;;
    t) template=${OPTARG} ;;
    u) url=${OPTARG} ;;
    *) exit 64 ;; #EX_USAGE
    esac
done
shift $((${OPTIND}-1))

if [ ! ${url-} ]
then
    url=http://${host}:${port}/
    trap 'kill -SIGINT %1' EXIT
    sam local start-api \
            ${host+--host ${host}} \
            ${port+--port ${port}} \
            ${template+--template ${template}} \
            ${project+--docker-volume-basedir ${project}} \
            --region ap-southeast-2 & #> ${out}/stdout.log 2> ${out}/stderr.log &

    sleep 5s
fi

echo Using ${url}

some_json=$(mktemp)

jq -n '{"test": "body"}' > ${some_json}

curl -vf -T ${some_json} ${url}some.json \
        --next "${url}?q=hello" \
        --next "${url}home?p=v1&p=v2&x&y=1" #> ${out}/curl.stdout.log 2> ${out}/curl.stderr.log
