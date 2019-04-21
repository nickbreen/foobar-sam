SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath ${<D}),dst=/app \
         	--mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = -vvv --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "-" $$2 "." $$3 } \
	else { print $$1}}')

.PHONY: buid clean deploy-ci update

build: composer.lock composer.json
	echo $(version)
	exit 1
	mkdir -p out
	cp -t out/ $^
	cd out
	$(composer) config version $(version)
	$(composer) config version
	$(composer) install --prefer-dist
	$(composer) archive

clean:
	rm -rf out/

deploy-ci: build/* ci/*
	stack=lambci template=ci/lambci.yaml ci/cfn.sh

update: composer.json
	$(composer) outdated --direct --strict || $(composer) update --prefer-dist
