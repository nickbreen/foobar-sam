SHELL = /bin/sh
bzip2 = lbzip2

docker = docker run --rm \
         	--mount type=bind,src=$(realpath .),dst=/app \
         	--env COMPOSER_CACHE_DIR=/app/$(cache)/composer \
         	--user $$(id -u):$$(id -g)

composer_args = --no-interaction

composer = $(docker) composer $(composer_args)

version = $(shell git describe | awk -F- '{ \
	gsub(/^v/, "", $$1); \
	if ($$2 && $$3) { print $$1 "+" $$2 "." $$3 } \
	else { print $$1}}')

cache = .cache
out = out
src = src

.PHONY: build clean outdated update test int acc til

build: $(addprefix $(out)/layer-,php wp bootstrap) $(addprefix $(out)/func-,js sh php) FORCE

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

$(out)/sam.yaml: $(src)/sam.yaml $(out)/layer-php $(out)/layer-wp $(out)/layer-bootstrap $(out)/func-sh
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

$(out)/func-php: $(src)/func-php/index.php
	rm -rf $@; mkdir $@
	cp -t $@ $^

$(out)/func-sh: $(src)/func-sh/handler.sh
	rm -rf $@; mkdir $@
	cp -t $@ $^

$(out)/func-js: $(src)/func-js/index.js $(src)/func-js/package.json
	rm -rf $@; mkdir $@
	cp -t $@ $^
	npm --cache $(cache)/npm --prefix $@ install --only=production

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

$(out)/layer-bootstrap: $(src)/layer-bootstrap/bootstrap.sh
	rm -rf $@; mkdir -p $@
	cp $< $@/bootstrap
	chmod +x $@/bootstrap

clean:
	rm -rf $(out)/*

outdated: $(src)/layer-wp.outdated $(src)/func-js.outdated

$(out)/layer-wp.outdated: $(out)/layer-wp
	$(composer) outdated --working-dir=$< --direct --strict | tee $@

$(out)/func-js.outdated: $(out)/func-js
	npm outdated --prefix=$< | tee $@

update: $(out)/layer-wp
	$(composer) update --working-dir=$< --prefer-dist
	cp -t . $</composer.lock

$(addprefix $(src)/layer-php/,libtidy-0.99.tgz libmcrypt-4.4.8.tgz php-7.3.3.tgz):
	wget --no-verbose --timestamping --directory-prefix=$(@D) https://lambci.s3.amazonaws.com/binaries/$(@F)

test: int

int: $(out)/test/int
$(out)/test/int: $(src)/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	sam local generate-event apigateway aws-proxy | tee /dev/stderr |\
			sam local invoke --template src/sam.yaml\
					--docker-volume-basedir .\
					--log-file $@/sam.log\
					--layer-cache-basedir $@/sam.layer.cache\
					WordPress | tee $@/invoke.out >&2
	cat $@/sam.log >&2

acc: $(out)/test/acc
$(out)/test/acc: $(src)/test $(src)/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	$(src)/test/test.sh -P $(realpath $(src)) -o $@ -s $(realpath $<) -t $(realpath $(src)/sam.yaml)

til: url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
til: $(out)/test/til
$(out)/test/til: $(src)/test $(src)/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	$(src)/test/test.sh -P $(realpath $(src)) -o $@ -s $(realpath $<) -t $(realpath $(src)/sam.yaml) -u $(url)

FORCE: