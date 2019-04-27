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

.PHONY: build clean outdated update int acc til

sam_deps = src/sam.yaml out/func-php out/layer-php/layer-1.d

build: out/func-php out/layer-php FORCE

clean:
	rm -rf out/*

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

out/sam.yaml: $(sam_deps)
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

# Application/Function

src/func-php/composer.phar:
	curl -fJLR -z ${@} -o ${@} https://getcomposer.org/download/$(composer_version)/composer.phar
	curl -fJLR -z ${@}.sha256sum -o ${@}.sha256sum https://getcomposer.org/download/$(composer_version)/composer.phar.sha256sum
	cd ${@D}; sha256sum -c ${@F}.sha256sum
	chmod +x ${@}

out/func-php: src/func-php/composer.json src/func-php/composer.lock src/func-php/handler.php src/func-php/wp-config.php #src/func-php/bootstrap
	rm -rf $@; mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
	$(composer) config --working-dir=$@ version $(version)

src/event.json:
	sam local generate-event apigateway aws-proxy > $@

out/layer-php/image: tag = layer-php:latest
out/layer-php/image: src/img2lambda/linux-amd64-img2lambda src/layer-php/*
	rm -rf $@; mkdir -p ${@D}
	docker build --tag $(tag) src/layer-php
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

install: src/func-php
	$(composer) install --working-dir=$< --prefer-dist

outdated: src/func-php
	$(composer) outdated --working-dir=$< --direct --strict

update: src/func-php
	$(composer) update --working-dir=$< --prefer-dist

# Testing

int: out/test/int
out/test/int: $(sam_deps) src/event.json FORCE
	rm -rf $@; mkdir -p $@
	sam local invoke --event src/event.json --template src/sam.yaml --docker-volume-basedir . Function > $@/invoke.out
	jq -r 'if .isBase64Encoded then .body | @base64d else .body end' < $@/invoke.out

acc: out/test/acc
out/test/acc: src/test/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -o $@ -t $(realpath src/sam.yaml)

til: url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
til: out/test/til
out/test/til: src/test/* $(sam_deps) FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -o $@ -t $(realpath src/sam.yaml) -u $(url)

FORCE: