SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath ${<D}),dst=/app \
         	--mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = -vvv --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe --abbrev=0)

.PHONY: buid clean deploy-ci update

build: composer.lock
	$(composer) config version $(version)
	$(composer) config version
	$(composer) install --prefer-dist
	$(composer) archive
	git checkout composer.json

clean:
	rm -rf wp wp-content foobar-wp-$(version).tar foobar-wp-$(version).tar.bz2

deploy-ci: build/* ci/*
	stack=lambci template=ci/lambci.yaml ci/cfn.sh

update: composer.json
	$(composer) outdated --direct --strict || $(composer) update --prefer-dist
