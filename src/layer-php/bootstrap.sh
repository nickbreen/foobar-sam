#!/usr/bin/env sh

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

while true
do
	HEADERS="$(mktemp)"
	REQUEST="$(mktemp)"
	RESPONSE="$(mktemp)"
	curl -fsS -LD "${HEADERS}" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next" -o "${REQUEST}"

	REQUEST_ID=$(sed -n -E '/Lambda-Runtime-Aws-Request-Id/I s/^.*:\s*([-[:xdigit:]]+).*$/\1/ p' "${HEADERS}")
	test "${REQUEST_ID}"

	php -f "${_HANDLER}" < "${REQUEST}" > "${RESPONSE}"

	curl -fsS "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/${REQUEST_ID}/response" -d "@${RESPONSE}"
done
