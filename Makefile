SHELL = /bin/sh
bzip2 = lbzip2

composer_args = -vvv --no-interaction

composer = docker run --rm \
              	 --mount type=bind,src=$(realpath ${<D}),dst=/app \
              	 --mount type=bind,src=$(realpath ${<D}/.cache),dst=/tmp/cache \
              	 --tmpfs /tmp:rw,noexec,nosuid \
              	 --user $$(id -u):$$(id -g) \
              	 composer $(composer_args)

version = $(shell git describe)

.PHONY: clean

wp.tar.bz2: wp.tar
	$(bzip2) --keep --force $<

wp.tar: composer.lock
	$(composer) config version $(version)
	$(composer) install --prefer-dist
	$(composer) archive --format=tar --dir=/app --file=$(basename $@)

clean:
	rm -rf wp wp-content wp.tar wp.tar.bz2

