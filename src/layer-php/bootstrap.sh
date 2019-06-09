#!/usr/bin/env bash

set -xeuo pipefail
shopt -s extglob

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

# CGI Environment Variables https://tools.ietf.org/html/rfc3875
declare AUTH_TYPE
declare CONTENT_LENGTH=0
declare CONTENT_TYPE='application/octet-stream'
declare GATEWAY_INTERFACE='CGI/1.1'
declare PATH_INFO
declare PATH_TRANSLATED
declare QUERY_STRING
declare REMOTE_ADDR
declare REMOTE_HOST
declare REMOTE_IDENT
declare REMOTE_USER
declare REQUEST_METHOD
declare SCRIPT_NAME
declare SERVER_NAME
declare SERVER_PORT
declare SERVER_PROTOCOL='HTTP/1.1'
declare SERVER_SOFTWARE=${AWS_EXECUTION_ENV-unknown}

# Lambda Runtime API Headers https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html#runtimes-api-next
declare lambda_runtime_aws_request_id # The request ID, which identifies the request that triggered the function invocation.
declare lambda_runtime_deadline_ms # The date that the function times out in Unix time milliseconds.
declare lambda_runtime_invoked_function_arn # The ARN of the Lambda function, version, or alias that's specified in the invocation.
declare lambda_runtime_trace_id # The AWS X-Ray tracing header.
declare lambda_runtime_client_context # For invocations from the AWS Mobile SDK, data about the client application and device.
declare lambda_runtime_cognito_identity # For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.

# Extra PHP Stuff
declare auto_prepend_file

test -f ${_HANDLER} && php -l ${_HANDLER}
if test -n ${auto_prepend_file-}
then
	test -f ${auto_prepend_file-} && php -l ${auto_prepend_file-}
fi

while true
do
	declare headers="$(mktemp)" request="$(mktemp)" response="$(mktemp)"
	curl -fsSL -D "${headers}" -o "${request}" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next"

	while IFS=: read header value
	do
		value=${value##+([[:space:]])}; value=${value%%+([[:space:]])}

		case ${header} in
		Lambda-Runtime-Aws-Request-Id) lambda_runtime_aws_request_id="${value}";;
		Lambda-Runtime-Deadline-Ms) lambda_runtime_deadline_ms="${value}";;
		Lambda-Runtime-Invoked-Function-Arn) lambda_runtime_invoked_function_arn="${value}";;
		Lambda-Runtime-Trace-Id) lambda_runtime_trace_id="${value}";;
		Lambda-Runtime-Client-Context) lambda_runtime_client_context="${value}";;
		Lambda-Runtime-Cognito-Identity) lambda_runtime_cognito_identity="${value}";;
		esac
	done < ${headers}

	php ${auto_prepend_file+-d auto_prepend_file=${auto_prepend_file}} -f "${_HANDLER}" < "${request}" > "${response}"

	cat ${response}; echo

	curl -fsS -d "@${response}" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/${lambda_runtime_aws_request_id}/response"
	rm ${headers} ${request} ${response}
done
