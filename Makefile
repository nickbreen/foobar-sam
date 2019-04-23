SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath .),dst=/app \
         	--mount type=bind,src=$(realpath .cache),dst=/tmp/cache \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "+" $$2 "." $$3 } \
	else { print $$1}}')

out = out
src = src


.PHONY: archive build clean outdated sam-deploy update test

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

$(out)/sam.yaml: $(src)/sam.yaml $(out)/layer-php $(out)/layer-wp $(out)/layer-bootstrap $(out)/wp
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

$(out)/wp: $(src)/wp/index.php $(src)/wp/package.json $(src)/wp/index.js
	rm -rf $@; mkdir $@
	cp -t $@ $^
	npm --cache .cache.npm --prefix $@ install --only=production

$(out)/layer-wp: $(src)/layer-wp/*
	rm -rf $@; mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
	$(composer) config --working-dir=$@ version $(version)

$(out)/layer-php: $(src)/layer-php/*
	rm -rf $@; mkdir -p $@/lib
	tar xf $(src)/layer-php/libmcrypt-4.4.8.tgz --directory=$@/lib --strip-components=2
	tar xf $(src)/layer-php/libtidy-0.99.tgz --directory=$@/lib --strip-components=2
	tar xf $(src)/layer-php/php-7.3.3.tgz --directory=$@ --strip-components=1
	cp -r -t $@ $(src)/layer-php/etc

$(out)/layer-bootstrap: $(src)/layer-bootstrap/bootstrap.php
	rm -rf $@; mkdir -p $@
	cp $< $@/bootstrap
	chmod +x $@/bootstrap

clean:
	rm -rf $(out)/*

outdated: $(src)/layer-wp.outdated
$(out)/layer-wp.outdated: $(out)/layer-wp
	$(composer) outdated --working-dir=$< --direct --strict | tee -a $@

update: $(out)/layer-wp
	$(composer) update --working-dir=$< --prefer-dist
	cp -t . $</composer.lock

$(addprefix $(src)/layer-php/,libtidy-0.99.tgz libmcrypt-4.4.8.tgz php-7.3.3.tgz):
	wget --no-verbose --timestamping --directory-prefix=$(@D) https://lambci.s3.amazonaws.com/binaries/$(@F)

live_url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
local_url = http://localhost:3000/
test: $(out)/test
$(out)/test: $(out)/layer-php $(out)/layer-wp $(out)/layer-bootstrap $(out)/wp $(src)/sam.yaml FORCE
	rm -rf $@; mkdir -p $@
	@if ! curl -sf $(local_url); then echo Start the SAM Local API; \
		echo sam local start-api \
				--host localhost \
				--port 3000 \
				--template $(src)/sam.yaml \
				--docker-volume-basedir src \
				--log-file $@/sam.log \
				--layer-cache-basedir $@/sam.layer.cache \
				--region ap-southeast-2; \
		read ARG; \
	fi

	curl -vf -T src/test/some.json $(local_url)some.json \
			$(local_url)license.txt \
			$(local_url)readme.html \
			$(local_url)?q=hello \
			"$(local_url)home?p=v1&p=v2&x&y=1"

FORCE: