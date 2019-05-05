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

.PHONY: deploy clean outdated update test int acc til

sam_deps = sam.yaml out/func-js out/layer-wp out/layer-php/layer-1.d

FORCE:

clean:
	rm -rf out/*

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

package: out/sam.yaml
out/sam.yaml: $(sam_deps)
	sam package --template-file sam.yaml --output-template-file $@ --s3-bucket wp.foobar.nz

# Function

test: out/func-js | FORCE
	cd $<; npm test

pack: out/func-js/func-js-$(version).tgz
out/func-js/func-js-$(version).tgz: out/func-js
	rm -rf $@
	cd $<; pwd; npm pack --dry-run --debug

out/func-js: src/func-js/*
	rm -rf $@; mkdir -p $@
	tar vc --exclude src/func-js/node_modules $^ | tar vx --directory $@ --strip-components 2
	cd $@; npm install; npm version $(version) --allow-same-version; npm shrinkwrap

# Layer PHP application

out/layer-wp: src/layer-wp/composer.json src/layer-wp/composer.lock src/layer-wp/wp-config.php src/layer-wp/index.php
	rm -rf $@; mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
#	$(composer) config --working-dir=$@ version $(version)

# Layer PHP runtime

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
	unzip -vt $@ bin/php bin/php-cgi etc/php.ini bootstrap

# make -o out/layer-php/layer-1.zip out/layer-php/layer-1.d -B
out/layer-php/layer-%.d: out/layer-php/layer-%.zip
	rm -rf $@; mkdir -p $@
	unzip -d $@ $<

src/layer-php/php-src-php-$(php_version).tar.gz:
	curl -fJLR -z ./${@} -o ${@} https://github.com/php/php-src/archive/php-$(php_version).tar.gz

out/func-php/composer.phar: composer_version = 1.8.5
out/func-php/composer.phar:
	rm -rf ${@D}; mkdir -p ${@D}
	curl -sSfJLR -z ${@} -o ${@} https://getcomposer.org/download/$(composer_version)/composer.phar
	curl -sSfJLR -z ${@}.sha256sum -o ${@}.sha256sum https://getcomposer.org/download/$(composer_version)/composer.phar.sha256sum
	cd ${@D}; sha256sum -c ${@F}.sha256sum
	chmod +x ${@}

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

src/test/event.json:
	sam local generate-event apigateway aws-proxy > $@

#test: out/test/test-echo out/test/test-db out/test/test-wp

debug-%: DEBUG_PORT = 5858
debug-echo: test-echo
debug-db: test-db
debug-wp: test-wp
debug-int: int

test-echo: doc_root = /var/task/echo
test-echo: out/test/test-echo
test-db: doc_root = /var/task/db
test-db: out/test/test-db
test-wp: doc_root = /opt/
test-wp: out/test/test-wp

out/test/test-%: db_host = $(file < out/test/mysql.addr)
out/test/test-%: src/test/%/expected.out $(sam_deps) src/test/event.json out/test/mysql.addr FORCE
	rm -rf $@; mkdir -p $@

	test -n "$(db_host)"
	test -n "$(db_name)"
	test -n "$(db_user)"
	test -n "$(db_pass)"

	sam local invoke $(patsubst %,--debug-port %,$(DEBUG_PORT)) \
			--skip-pull-image \
			--event src/test/event.json \
			--template src/sam.yaml \
			--docker-volume-basedir . \
			--parameter-overrides "\
				ParameterKey=documentRoot,ParameterValue=$(doc_root) \
				ParameterKey=dbHost,ParameterValue=$(db_host) \
				ParameterKey=dbName,ParameterValue=$(db_name) \
				ParameterKey=dbUser,ParameterValue=$(db_user) \
				ParameterKey=dbPass,ParameterValue=$(db_pass) \
			" function > $@/function.out

	jq -r '.headers | to_entries[] | (.key + ": " + .value)' < $@/function.out
	jq -r 'if .isBase64Encoded then .body | @base64d else .body end' < $@/function.out > $@/actual.out

	diff -B src/test/$*/expected.out $@/actual.out || grep Error $@/actual.out > /dev/null

db_name = wordpress
db_user = wordpress
db_pass = wordpress

# same as RDS, helps to avoid password version gripes in v8
mysql_version = 5.6.34

mysql: out/test/mysql.id
out/test/mysql.id:
	rm -rf $@; mkdir -p ${@D}
	docker run --rm -d \
			-e MYSQL_DATABASE=$(db_name) \
			-e MYSQL_USER=$(db_user) \
			-e MYSQL_PASSWORD=$(db_pass) \
			-e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
			mysql:$(mysql_version) | tee $@
	test -s $@

out/test/mysql.addr: cont_id = $(file < out/test/mysql.id)
out/test/mysql.addr: out/test/mysql.id
	rm -rf $@; mkdir -p ${@D}
	test -n "$(cont_id)"
	docker inspect -f '{{.NetworkSettings.IPAddress}}' $(cont_id) | tr -d '\n' | tee $@
	test -s $@

kill-mysql: cont_id = $(file < out/test/mysql.id)
kill-mysql:
	rm out/test/mysql.*
	test -n "$(cont_id)" && docker stop $(cont_id)

sam: out/test/sam.pid
out/test/sam.pid: db_host = $(file < out/test/mysql.addr)
out/test/sam.pid: out/test/mysql.addr
	sam local start-api $(patsubst %,--debug-port %,$(DEBUG_PORT)) \
			--port 3000 \
			--skip-pull-image \
			--template src/sam.yaml \
			--docker-volume-basedir . \
			--parameter-overrides "\
				ParameterKey=documentRoot,ParameterValue=/opt \
				ParameterKey=dbHost,ParameterValue=$(db_host) \
				ParameterKey=dbName,ParameterValue=$(db_name) \
				ParameterKey=dbUser,ParameterValue=$(db_user) \
				ParameterKey=dbPass,ParameterValue=$(db_pass) \
			" & echo $$! > $@
	sleep 5s

kill-sam: pid = $(file < out/test/sam.pid)
kill-sam:
	rm out/test/sam.pid
	kill -6 $(pid)

int: out/test/int
out/test/int:  src/test/int/expected.*.txt $(sam_deps) out/test/mysql.addr out/test/sam.pid FORCE
	rm -rf $@; mkdir -p $@

	curl -vsi localhost:3000/ -w @src/test/int/expected.fmt -o $@/actual.1.response > $@/actual.1.txt
	cat $@/actual.1.response; echo
	diff src/test/int/expected.1.txt $@/actual.1.txt || diff src/test/int/expected.1nodata.txt $@/actual.1.txt

	curl -vsi localhost:3000/wp/wp-admin/install.php -w @src/test/int/expected.fmt -o $@/actual.2.response > $@/actual.2.txt
	cat $@/actual.2.response; echo
	diff src/test/int/expected.2.txt $@/actual.2.txt

	curl -vsi 'localhost:3000/wp/wp-includes/css/buttons.min.css?ver=5.1.1' -w @src/test/int/expected.fmt -o $@/actual.3.response > $@/actual.3.txt
	cat $@/actual.3.response; echo
	diff src/test/int/expected.3.txt $@/actual.3.txt

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

