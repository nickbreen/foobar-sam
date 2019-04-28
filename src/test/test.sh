#!/usr/bin/env bash

set -veuo pipefail

declare OPT debug host=localhost out port=3000 dir src template url params

#trap 'pkill sam' ERR

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
    trap 'kill -SIGINT %1; docker rm --force --volumes mysql' EXIT

    docker run --name mysql --rm -d \
    		--env MYSQL_ROOT_PASSWORD=rootpasswd \
    		--env MYSQL_DATABASE=wordpress \
    		--env MYSQL_PASSWORD=wordpress \
    		--env MYSQL_USER=wordpress \
    		mysql

    sam local start-api \
            ${host+--host ${host}} \
            ${port+--port ${port}} \
            ${debug+--debug-port ${debug}} \
            ${template+--template ${template}} \
            ${dir+--docker-volume-basedir ${dir}} \
            ${params+--parameter-overrides ${params}} \
            --region ap-southeast-2 &

    sleep 5s
fi

echo Using ${url}

curl -vf -T ${src}/expected.json ${url}some.json -o ${out}/some.json
diff ${src}/expected.json ${out}/some.json

curl -vf "${url}?q=hello" -o ${out}/hello
diff /dev/null ${out}/hello

curl -vf  "${url}home?p=v1&p=v2&x&y=1" -o ${out}/home
diff /dev/null ${out}/home

wait
