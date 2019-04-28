#!/usr/bin/env bash

set -euo pipefail

declare OPT debug host=localhost out port=3000 dir src template url params

trap 'pkill sam' ERR

while getopts "D:d:h:o:P:p:s:t:u:" OPT
do
    case ${OPT} in
    D) dir=${OPTARG} ;;
    d) debug=${OPTARG} ;;
    h) host=${OPTARG} ;;
    o) out=${OPTARG} ;;
    P) params=${OPTARG} ;;
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
            ${debug+--debug-port ${debug}} \
            ${template+--template ${template}} \
            ${dir+--docker-volume-basedir ${dir}} \
            ${params+--parameter-overrides ${params}} \
            --region ap-southeast-2 & #> ${out}/stdout.log 2> ${out}/stderr.log &

    sleep 5s
fi

echo Using ${url}

some_json=$(mktemp)

jq -nc '{"test": "body"}' > ${some_json}

curl -vf -T ${some_json} ${url}some.json -o ${out}/some.json
diff ${some_json} ${out}/some.json

curl -vf "${url}?q=hello" -o ${out}/hello
diff /dev/null ${out}/hello

curl -vf  "${url}home?p=v1&p=v2&x&y=1" -o ${out}/home  #> ${out}/curl.stdout.log 2> ${out}/curl.stderr.log
diff /dev/null ${out}/home

