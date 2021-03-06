SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath .),dst=/app \
         	--env COMPOSER_CACHE_DIR=/app/.cache/composer \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction --ignore-platform-reqs

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "+" $$2 "." $$3 } \
	else { print $$1}}')

.PHONY: deploy clean outdated update test int acc til test-mysql kill-mysql kill-sam

sam_deps = out/func-echo out/func-db out/func-js out/layer-wp/www out/layer-php/layer-1.d
#			$(shell find out/func-js out/layer-wp/www out/layer-php/layer-1.d -name node_modules -prune -o -print)

FORCE:

clean:
	rm -rf out/*

docker-clean:
	docker ps -qf status=exited  | xargs -r docker rm -fv
	docker image ls -f dangling=true -q | xargs -r docker image rm
	test -f out/layer-php.image && docker load -i out/layer-php.image || true

# Function

test: out/func-js | FORCE
	cd $<; npm test

pack: out/func-js/func-js-$(version).tgz
out/func-js/func-js-$(version).tgz: out/func-js/npm-shrinkwrap.json
	rm -rf $@; cd ${<D}; pwd; npm pack --dry-run --debug

out/%: src/%/*
	rm -rf $@; mkdir -p $@; cp -rt $@ $^

out/func-js: src/func-js src/func-js/*
	rm -rf $@; mkdir -p $@
	tar c --exclude node_modules $^ | tar x --directory $@ --strip-components 2
	cd $@; npm install; npm version $(version) --allow-same-version; npm shrinkwrap

# Layer PHP application

out/layer-wp/www: src/layer-wp/composer.json src/layer-wp/composer.lock src/layer-wp/wp-config.php src/layer-wp/index.php
	rm -rf $@; mkdir -p $@; cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
#	$(composer) config --working-dir=$@ version $(version)

out/layer-wp/bin/wp: out/layer-wp/bin/wp-cli-2.2.0.phar
	ln -sf $(notdir $<) ${@}
	ls -l ${@D}

out/layer-wp/bin/wp-cli-%.phar:
	curl -sSfJLR -o $@ -z $@ https://github.com/wp-cli/wp-cli/releases/download/v${*}/wp-cli-${*}.phar
	chmod +x ${@}

# Layer PHP runtime

php_version = 7.3.6
out/layer-php.image: tag = layer-php:latest
out/layer-php.image: src/layer-php/php-src-php-$(php_version).tar.gz src/layer-php/*
	docker build --tag $(tag) --build-arg php_version=$(php_version) src/layer-php
	docker run --rm -i -v $$PWD/src/layer-php/index.php:/var/task/index.php:ro $(tag) handler.php
	docker save $(tag) --output $@

# make -o out/layer-php.image out/layer-php/layer-1.zip -B
out/layer-php/layer-%.zip: tag = layer-php:latest
out/layer-php/layer-%.zip: out/layer-php.image src/img2lambda/linux-amd64-img2lambda
	rm -rf $@; mkdir -p ${@D}
	docker load -i $<
	src/img2lambda/linux-amd64-img2lambda --image $(tag) --dry-run --output-directory ${@D}
	unzip -vt $@ bootstrap bin/php bin/php-cgi

# make -o out/layer-php/layer-1.zip out/layer-php/layer-1.d -B
out/layer-php/layer-%.d: out/layer-php/layer-%.zip
	rm -rf $@; mkdir -p $@
	unzip -d $@ $<

src/layer-php/php-src-php-%.tar.gz:
	curl -sSfJLR -z ./${@} -o ${@} https://github.com/php/php-src/archive/php-$*.tar.gz

out/func-php/composer.phar: composer_version = 1.8.5
out/func-php/composer.phar:
	rm -rf ${@D}; mkdir -p ${@D}
	curl -sSfJLR -z ${@} -o ${@} https://getcomposer.org/download/$(composer_version)/composer.phar
	curl -sSfJLR -z ${@}.sha256sum -o ${@}.sha256sum https://getcomposer.org/download/$(composer_version)/composer.phar.sha256sum
	cd ${@D}; sha256sum -c ${@F}.sha256sum
	chmod +x ${@}

# AWS img2lambda binary

src/img2lambda/linux-amd64-img2lambda: img2lambda_version = 0.2.0
src/img2lambda/linux-amd64-img2lambda:
	curl -sSfJLR -z $@ -o $@ https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(img2lambda_version)/linux-amd64-img2lambda
	curl -sSfJLR -z $@.sha256 -o $@.sha256 https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(img2lambda_version)/linux-amd64-img2lambda.sha256
	cd ${@D}; sha256sum -c ${@F}.sha256
	chmod +x $@

# AWS img2lambda source & example

out/img2lambda: out/img2lambda/scripts/build_example.sh
	rm -rf $@; mkdir -p ${@}
	cd $@; ./scripts/build_example.sh

out/img2lambda/scripts/build_example.sh: img2lambda_version = 0.2.0
out/img2lambda/scripts/build_example.sh: src/img2lambda/img2lambda.tar-$(img2lambda_version).gz
	rm -rf $@; mkdir -p ${@}
	tar xf $< --directory $@ --strip-components 1

src/img2lambda/img2lambda.tar-$(img2lambda_version).gz:
	rm -rf $@; mkdir -p ${@D}
	curl -sSfJLR -z ${@} -o ${@} https://github.com/awslabs/aws-lambda-container-image-converter/archive/$(img2lambda_version).tar.gz

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

test-all: out/test/test-echo out/test/test-hello out/test/test-db out/test/test-wp

debug-%: DEBUG_PORT = 5858
debug-echo: out/test/test-echo
debug-db: out/test/test-db
debug-wp: out/test/test-wp
debug-int: int

out/test/test-hello: dir_index = hello.php
out/test/test-echo: dir_index = echo.php

out/test/test-db: dir_index = db.php
out/test/test-db: out/test/mysql.addr
out/test/test-db: db_host = $(file < out/test/mysql.addr)

out/test/test-wp: doc_root = /opt/www
out/test/test-wp: out/test/mysql.addr
out/test/test-wp: db_host = $(file < out/test/mysql.addr)

out/test/test-%: comma = ,
out/test/test-%: param = $(if $(2),ParameterKey=$1$(comma)ParameterValue=$(2))
out/test/test-%: src/test/%/expected.out $(sam_deps) src/test/event.json FORCE
	rm -rf $@; mkdir -p $@

	sam local invoke $(patsubst %,--debug-port %,$(DEBUG_PORT)) --debug \
			--skip-pull-image \
			--event src/test/event.json \
			--template sam.yaml \
			--docker-volume-basedir . \
			--parameter-overrides "\
				$(call param,documentRoot,$(doc_root)) \
				$(call param,directoryIndex,$(dir_index)) \
				$(call param,dbHost,$(db_host)) \
				$(call param,dbName,$(db_name)) \
				$(call param,dbUser,$(db_user)) \
				$(call param,dbPass,$(db_pass)) \
				$(call param,wpDebug,true) \
			" phpCgi > $@/function.out

	jq -r '.headers | to_entries[] | (.key + ": " + .value)' < $@/function.out
	jq -r 'if .isBase64Encoded then .body | @base64d else .body end' < $@/function.out > $@/actual.out

	diff -Bu src/test/$*/expected.out $@/actual.out || grep Error $@/actual.out > /dev/null

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
	sleep 10s # wait for DB to start
	test -s $@

out/test/mysql.addr: cont_id = $(file < out/test/mysql.id)
out/test/mysql.addr: out/test/mysql.id
	rm -rf $@; mkdir -p ${@D}
	test -n "$(cont_id)"
	docker inspect -f '{{.NetworkSettings.IPAddress}}' $(cont_id) | tr -d '\n' | tee $@
	test -s $@

test-mysql: db_host = $(file < out/test/mysql.addr)
test-mysql: out/test/mysql.addr
	echo "show databases;" | docker run --rm mysql:$(mysql_version) mysql -h $(db_host) -uroot

kill-mysql: cont_id = $(file < out/test/mysql.id)
kill-mysql:
	rm -f out/test/mysql.*
	+test -n "$(cont_id)" && docker stop $(cont_id)

sam: out/test/sam.pid
out/test/sam.pid: db_host = $(file < out/test/mysql.addr)
out/test/sam.pid: sam.yaml out/test/mysql.addr
	sam local start-api $(patsubst %,--debug-port %,$(DEBUG_PORT)) --debug -log-file /dev/stderr \
			--port 3000 \
			--skip-pull-image \
			--template $< \
			--docker-volume-basedir . \
			--parameter-overrides "\
				ParameterKey=documentRoot,ParameterValue=/opt \
				ParameterKey=wpDebug,ParameterValue=true \
				ParameterKey=dbHost,ParameterValue=$(db_host) \
				ParameterKey=dbName,ParameterValue=$(db_name) \
				ParameterKey=dbUser,ParameterValue=$(db_user) \
				ParameterKey=dbPass,ParameterValue=$(db_pass) \
			" & echo $$! > $@
	sleep 5s

kill-sam: pid = $(file < out/test/sam.pid)
kill-sam:
	test -n "$(pid)" && kill -6 $(pid) && rm -f out/test/sam.pid

int: out/test/sam.pid out/test/int
out/test/%: url = http://localhost:3000/
out/test/%: src/test/* src/test/int/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@

	echo URL: $(url)
	test -n "$(url)"

	curl -Ssi $(url) -w @src/test/int/expected.fmt -o $@/actual.1.response > $@/actual.1.txt
	cat $@/actual.1.response; echo
	diff src/test/int/expected.1.txt $@/actual.1.txt || diff src/test/int/expected.1nodata.txt $@/actual.1.txt

	curl -Ssi $(url)wp/wp-admin/install.php -w @src/test/int/expected.fmt -o $@/actual.2.response > $@/actual.2.txt
	cat $@/actual.2.response; echo
	diff src/test/int/expected.2.txt $@/actual.2.txt

	curl -Ssi '$(url)wp/wp-includes/css/buttons.min.css?ver=5.1.1' -w @src/test/int/expected.fmt -o $@/actual.3.response > $@/actual.3.txt
	cat $@/actual.3.response; echo
	diff src/test/int/expected.3.txt $@/actual.3.txt

# Deployment & Live Testing

package: out/wp-sam.yaml
out/%.yaml: sam.yaml $(sam_deps)
	rm -f $@
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

deploy: out/wp-sam.url
out/%.url: out/%.yaml
	rm -f $@
	sam deploy --template-file $< --stack-name $* --capabilities CAPABILITY_IAM --parameter-overrides \
				dbName=/$*/db/name \
				dbUser=/$*/db/user \
				dbPass=/$*/db/password

	aws cloudformation describe-stacks --stack-name $* | \
    	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue' | tee out/$*.url

acc: url = $(file < out/wp-sam-test.url)
acc: out/wp-sam-test.url out/test/acc

til: url = $(file < out/wp-sam.url)
til: out/wp-sam.url out/test/til
