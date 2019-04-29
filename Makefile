SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath .),dst=/app \
         	--env COMPOSER_CACHE_DIR=/app/.cache/composer \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "+" $$2 "." $$3 } \
	else { print $$1}}')

img2lambda_version = 0.1.1
php_version = 7.3.4
composer_version = 1.8.5

.PHONY: clean outdated update test int acc til

sam_deps = src/sam.yaml out/func-js out/layer-wp out/layer-php/layer-1.d

clean:
	rm -rf out/*

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

out/sam.yaml: $(sam_deps)
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

# Function

out/func-js: src/func-js/package-lock.json src/func-js/package.json src/func-js/*.js src/func-js/*.php out/php.ini
	rm -rf $@; mkdir $@
	cp -t $@ $^
	cd $@; npm install

# Layer PHP application

out/layer-wp: src/layer-wp/composer.json src/layer-wp/composer.lock src/layer-wp/wp-config.php
	rm -rf $@; mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
#	$(composer) config --working-dir=$@ version $(version)

# Layer PHP runtime

out/php.ini: src/layer-php/php-src-php-$(php_version).tar.gz
	tar xf $< -O php-src-php-7.3.4/php.ini-production > $@

out/layer-php/image: tag = layer-php:latest
out/layer-php/image: src/img2lambda/linux-amd64-img2lambda src/layer-php/*
	rm -rf $@; mkdir -p ${@D}
	docker build --tag $(tag) --build-arg php_version=7.3.4 src/layer-php
	docker run --rm -i $(tag) handler.php 'Hello Lambda!'
	docker save $(tag) --output $@

# make -o out/layer-php/image out/layer-php/layer-1.zip -B
out/layer-php/layer-%.zip: tag = layer-php:latest
out/layer-php/layer-%.zip: out/layer-php/image
	rm -rf $@; mkdir -p ${@D}
	docker load -i $<
	src/img2lambda/linux-amd64-img2lambda --image $(tag) --dry-run --output-directory ${@D}
	unzip -vt $@ bin/php bin/php-cgi bootstrap

# make -o out/layer-php/layer-1.zip out/layer-php/layer-1.d  -B
out/layer-php/layer-%.d: out/layer-php/layer-%.zip
	rm -rf $@; mkdir -p $@
	unzip -d $@ $<

src/layer-php/php-src-php-$(php_version).tar.gz:
	curl -fJLR -z ./${@} -o ${@} https://github.com/php/php-src/archive/php-$(php_version).tar.gz

# AWS img2lambda binary

src/img2lambda/linux-amd64-img2lambda:
	curl -fJLR -z $@ -o $@ https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(img2lambda_version)/linux-amd64-img2lambda
	curl -fJLR -z $@.sha256 -o $@.sha256 https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(img2lambda_version)/linux-amd64-img2lambda.sha256
	cd ${@D}; sha256sum -c ${@F}.sha256
	chmod +x $@

# AWS img2lambda source & example

out/img2lambda: src/img2lambda/img2lambda.tar-$(img2lambda_version).gz
	rm -rf $@; mkdir -p ${@}
	tar xf $< --directory $@ --strip-components 1
	find $@
	cd $@; ./scripts/build_example.sh

src/img2lambda/img2lambda.tar-$(img2lambda_version).gz:
	rm -rf $@; mkdir -p ${@D}
	curl -fJLR -z ${@} -o ${@} https://github.com/awslabs/aws-lambda-container-image-converter/archive/$(img2lambda_version).tar.gz

# Dev Utilities

install: src/layer-wp
	$(composer) install --working-dir=$< --prefer-dist

outdated: src/layer-wp
	$(composer) outdated --working-dir=$< --direct --strict

update: src/layer-wp
	$(composer) update --working-dir=$< --prefer-dist

# Testing

src/test/expected.json:
	jq -nc '{test:"body"}' | unix2dos > $@

src/test/event.json:
	sam local generate-event apigateway aws-proxy > $@

test: out/test/test-echo
out/test/test-echo: $(sam_deps) src/test/event.json src/test/expected.out FORCE
	rm -rf $@; mkdir -p $@

	sam local invoke \
			$(patsubst %,--debug-port %,$(DEBUG_PORT)) \
			--event src/test/event.json \
			--template src/sam.yaml \
			--docker-volume-basedir . \
			--parameter-overrides ParameterKey=script,ParameterValue=echo.php \
			function > $@/function.out
	jq -r 'if .isBase64Encoded then .body | @base64d else .body end' < $@/function.out > $@/actual.out
	diff src/test/expected.out $@/actual.out

test-wp: out/test/test-wp
out/test/test-wp: net_id = $(file < out/test/mysql.net)
out/test/test-wp: $(sam_deps) src/test/event.json src/test/expected.out out/test/env.json FORCE
	rm -rf $@; mkdir -p $@

	sam local invoke --debug \
			$(patsubst %,--debug-port %,$(DEBUG_PORT)) \
			--env-vars out/test/env.json \
			--event src/test/event.json \
			--docker-network $(net_id) \
			--template src/sam.yaml \
			--docker-volume-basedir . \
			--parameter-overrides ParameterKey=script,ParameterValue=wp.php \
			function > $@/function.out
	jq -r 'if .isBase64Encoded then .body | @base64d else .body end' < $@/function.out | tee $@/actual.out
	grep Error $@/actual.out > /dev/null

out/test/env.json: db_host = $(file < out/test/mysql.addr)
out/test/env.json: db_port = $(file < out/test/mysql.port)
out/test/env.json: out/test/mysql.addr out/test/mysql.port

	test -n $(db_host)
	test -n $(db_port)
	test -n $(db_name)
	test -n $(db_user)
	test -n $(db_pass)

	jq -n --arg db_host $(db_host) --arg db_port $(db_port) --arg db_name $(db_name) \
			--arg db_user $(db_user) --arg db_pass $(db_pass) \
			'{Function:{db_host: $$db_host, db_port: $$db_port, db_name: $$db_name, db_user: $$db_user, db_pass: $$db_pass}}' \
			| tee $@

db_name = wordpress
db_user = wordpress
db_pass = wordpress

out/test/mysql.net:
	rm -rf $@; mkdir -p ${@D}
	docker network create mysql | tr -d '\n' | tee $@
	test -s $@

mysql: out/test/mysql.id
out/test/mysql.id: net_id = $(file < out/test/mysql.net)
out/test/mysql.id: out/test/mysql.net
	rm -rf $@; mkdir -p ${@D}

	test -n $(net_id)
	test -n $(db_name)
	test -n $(db_user)
	test -n $(db_pass)

	docker run --rm -d --network $(net_id) \
			-e MYSQL_NAME=$(db_name) \
			-e MYSQL_USER=$(db_user) \
			-e MYSQL_PASSWORD=$(db_pass) \
			-e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
			-P mysql > $@
	docker ps -f id=$(cont_id)
	test -s $@

out/test/mysql.addr: net_id = $(file < out/test/mysql.net)
out/test/mysql.addr: cont_id = $(file < out/test/mysql.id)
out/test/mysql.addr: out/test/mysql.id out/test/mysql.net
	rm -rf $@; mkdir -p ${@D}
	test -n $(cont_id)
	docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "'$(net_id)'"}}{{.IPAddress}}{{end}}{{end}}' $(cont_id) | tr -d '\n' | tee $@
	test -s $@

out/test/mysql.port: cont_id = $(file < out/test/mysql.id)
out/test/mysql.port: out/test/mysql.id
	rm -rf $@; mkdir -p ${@D}
	test -n $(cont_id)
	docker port $(cont_id) 3306/tcp | cut -d: -f2 | tr -d '\n' | tee $@
	test -s $@

kill-mysql: cont_id = $(file < out/test/mysql.id)
kill-mysql:
	test -n $(cont_id)
	docker stop $(cont_id)
	rm out/test/mysql.id

int: out/test/int
out/test/int: src/test/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh \
			$(patsubst %,-d %,$(DEBUG_PORT)) \
			-s src/test \
			-D . \
			-o $@ \
			-t $(realpath src/sam.yaml) \
			-P ParameterKey=script,ParameterValue=echo.php

acc: out/test/acc
out/test/acc: src/test/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -m \
			$(patsubst %,-d %,$(DEBUG_PORT)) \
			-s src/test \
			-D . \
			-o $@ \
			-t $(realpath src/sam.yaml) \
			-P ParameterKey=script,ParameterValue=wp.php

til: url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
til: out/test/til
out/test/til: src/test/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -D . -o $@ -t $(realpath src/sam.yaml) -u $(url)

FORCE: