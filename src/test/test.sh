#!/usr/bin/env bash

set -xeuo pipefail

declare OPT debug host=localhost out port=3000 dir src template url params mysql

while getopts "D:d:h:mo:P:p:s:t:u:" OPT
do
    case ${OPT} in
    D) dir=${OPTARG} ;;
    d) debug=${OPTARG} ;;
    h) host=${OPTARG} ;;
    m) mysql=1 ;;
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


if [ ${mysql-} ]
then
    cont_id=$(docker run --rm -d -P \
    		--env MYSQL_ROOT_PASSWORD=rootpasswd \
    		--env MYSQL_DATABASE=wordpress \
    		--env MYSQL_PASSWORD=wordpress \
    		--env MYSQL_USER=wordpress \
    		mysql)

	db_host=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' ${cont_id}):$(docker port ${cont_id} 3306/tcp | cut -d: -f2)

    trap "docker kill ${cont_id}" EXIT
fi

if [ ! ${url-} ]
then
    url=http://${host}:${port}/
    trap 'kill -6 %1' EXIT
	pkill -6 sam || true

	if [ ${db_host-} ]
	then
		params="${params-} ParameterKey=dbHost,ParameterValue=${db_host}"
		params="${params} ParameterKey=dbName,ParameterValue=wordpress"
		params="${params} ParameterKey=dbUser,ParameterValue=wordpress"
		params="${params} ParameterKey=dbPass,ParameterValue=wordpress"
	fi

    sam local start-api \
            ${host+--host ${host}} \
            ${port+--port ${port}} \
            ${debug+--debug-port ${debug}} \
            ${template+--template ${template}} \
            ${dir+--docker-volume-basedir ${dir}} \
            ${params+--parameter-overrides "${params}"} &

    sleep 5s
fi

echo Using ${url}

curl -v -T ${src}/expected.json ${url}some.json -o ${out}/some.json
diff ${src}/expected.json ${out}/some.json

curl -v "${url}?q=hello" -o ${out}/hello
diff /dev/null ${out}/hello

curl -v  "${url}home?p=v1&p=v2&x&y=1" -o ${out}/home
diff /dev/null ${out}/home

