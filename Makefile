SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath ${<D}),dst=/app \
         	--mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe --abbrev=0)

.PHONY: clean

foobar-wp-$(version).tar.bz2: foobar-wp-$(version).tar
	$(bzip2) --keep --force $<

foobar-wp-$(version).tar: composer.lock
	$(composer) config version $(version)
	$(composer) config version
	$(composer) install --prefer-dist
	$(composer) archive

clean:
	rm -rf wp wp-content foobar-wp-$(version).tar foobar-wp-$(version).tar.bz2
	git checkout composer.json

