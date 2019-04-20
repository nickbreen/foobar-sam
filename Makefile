SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath ${<D}),dst=/app \
         	--mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = -vvv --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe --abbrev=0)

.PHONY: clean update

foobar-wp-$(version).tar.bz2: foobar-wp-$(version).tar
	$(bzip2) --keep --force $<

foobar-wp-$(version).tar: composer.lock
	$(composer) config version $(version)
	$(composer) config version
	$(composer) install --prefer-dist
	$(composer) archive
	git checkout composer.json

clean:
	rm -rf wp wp-content foobar-wp-$(version).tar foobar-wp-$(version).tar.bz2

update: composer.json
	$(composer) outdated --direct --strict || $(composer) update --prefer-dist
