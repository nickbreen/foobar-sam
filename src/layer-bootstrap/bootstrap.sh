#!/bin/bash

set -xeuo pipefail

# AWS Lambda Environment Variables, per https://docs.aws.amazon.com/lambda/latest/dg/lambda-environment-variables.html
declare _HANDLER # The handler location configured on the function.
declare AWS_REGION # The AWS region where the Lambda function is executed.
declare AWS_EXECUTION_ENV # The runtime identifier, prefixed by AWS_Lambda_. For example, AWS_Lambda_java8.
declare AWS_LAMBDA_FUNCTION_NAME # The name of the function.
declare AWS_LAMBDA_FUNCTION_MEMORY_SIZE # The amount of memory available to the function in MB.
declare AWS_LAMBDA_FUNCTION_VERSION # The version of the function being executed.
declare AWS_LAMBDA_LOG_GROUP_NAME
declare AWS_LAMBDA_LOG_STREAM_NAME # The name of the Amazon CloudWatch Logs group and stream for the function.
declare AWS_ACCESS_KEY_ID
declare AWS_SECRET_ACCESS_KEY
declare AWS_SESSION_TOKEN # Access keys obtained from the function's execution role.
declare LANG #en_US.UTF-8. This is the locale of the runtime.
declare TZ # The environment's timezone (UTC). The execution environment uses NTP to synchronize the system clock.
declare LAMBDA_TASK_ROOT # The path to your Lambda function code.
declare LAMBDA_RUNTIME_DIR #The path to runtime libraries.
declare PATH #/usr/local/bin:/usr/bin/:/bin:/opt/bin
declare LD_LIBRARY_PATH #/lib64:/usr/lib64:$LAMBDA_RUNTIME_DIR:$LAMBDA_RUNTIME_DIR/lib:$LAMBDA_TASK_ROOT:$LAMBDA_TASK_ROOT/lib:/opt/lib
declare NODE_PATH #(Node.js) /opt/nodejs/node8/node_modules/:/opt/nodejs/node_modules:$LAMBDA_RUNTIME_DIR/node_modules
declare PYTHONPATH #(Python) $LAMBDA_RUNTIME_DIR.
declare GEM_PATH #(Ruby) $LAMBDA_TASK_ROOT/vendor/bundle/ruby/2.5.0:/opt/ruby/gems/2.5.0.
declare AWS_LAMBDA_RUNTIME_API # (custom runtime) The host and port of the runtime API.

echo _HANDLER:${_HANDLER}
echo AWS_EXECUTION_ENV:${AWS_EXECUTION_ENV:-N/A}
echo LAMBDA_RUNTIME_DIR:${LAMBDA_RUNTIME_DIR}
echo LAMBDA_TASK_ROOT:${LAMBDA_TASK_ROOT}

find ${LAMBDA_TASK_ROOT} ${LAMBDA_RUNTIME_DIR} /opt -name wp-content -prune -o -name wp -prune -o -executable -print

php=$(PATH="/opt/usr/bin:$PATH" which php)
pid_file=/tmp/php.pid

start_webserver()
{
    declare handler_file handler_dir
    IFS=/ read -ra handler_components <<< ${_HANDLER};
    handler_file=$(basename ${_HANDLER});
    handler_dir=$(dirname ${_HANDLER});
    ${php} -t ${handler_dir} -S localhost:8000 ${handler_file} &
    echo $! > ${pid_file}
}

stop_webserver()
{
    kill $(<${pid_file}) && rm ${pid_file}
}

trap 'stop_webserver' EXIT

# TODO fetch SSM Params needed by WP!

start_webserver

while true
do
    headers=$(mktemp)
    entity=$(mktemp)
    # GET http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next
    curl -sSfLD ${headers} -o ${entity} http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next

    cat ${headers} ${entity}

    invocation_id=$(sed -n '/^lambda-runtime-aws-request-id/Is/.*:\s*//' ${headers})
    # get lambda-runtime-aws-request-id header!
    # decode json
    # assemble root-relative URI from request (i.e. /foo/bar?fiz=faz
    # re-assemble request headers
    # proxy request to php server
    # POST http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$invocation_id/response
    curl -sSf --data=@${headers} --data-raw="\n\n" --data=@${entity} http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$invocation_id/response
done

