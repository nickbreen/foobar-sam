SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath ${<D}),dst=/app \
         	--mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "+" $$2 "." $$3 } \
	else { print $$1}}')

.PHONY: archive build clean deploy-ci outdated sam-deploy update

build: out

out: composer.lock composer.json index.php wp-config.php
	mkdir -p $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
	$(composer) config --working-dir=$@ version $(version)

deploy: sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

sam.yaml: wp.yaml out
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

archive: out
	$(composer) archive --working-dir=$< --format=zip

clean:
	rm -rf out/

deploy-ci: build/* ci/*
	stack=lambci template=ci/lambci.yaml ci/cfn.sh

outdated: out composer.json
	$(composer) outdated --working-dir=$< --direct --strict

update: out composer.json
	$(composer) update --working-dir=$< --prefer-dist
	cp -t . $</composer.lock

