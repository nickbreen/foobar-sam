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

.PHONY: archive build clean outdated sam-deploy update test

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

out/sam.yaml: src/sam.yaml out/layer-php out/layer-wp out/layer-bootstrap out/wp
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

out/wp: src/wp/package.json src/wp/index.js
	rm -rf $@
	mkdir $@
	cp -t $@ $^
	npm --cache .cache.npm --prefix $@ install --only=production

out/layer-wp: src/layer-wp/*
	rm -rf $@
	mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
	$(composer) config --working-dir=$@ version $(version)

out/layer-php: src/layer-php/*
	rm -rf $@
	mkdir -p $@/lib
	tar xf src/layer-php/libmcrypt-4.4.8.tgz --directory=$@/lib --strip-components=2
	tar xf src/layer-php/libtidy-0.99.tgz --directory=$@/lib --strip-components=2
	tar xf src/layer-php/php-7.3.3.tgz --directory=$@ --strip-components=1

out/layer-bootstrap: src/layer-bootstrap/bootstrap.sh
	rm -rf $@
	mkdir -p $@
	cp $< $@/bootstrap
	chmod +x $@/bootstrap

clean:
	rm -rf out/*

outdated: src/layer-wp.outdated
out/layer-wp.outdated: out/layer-wp
	$(composer) outdated --working-dir=$< --direct --strict | tee -a $@

update: out/layer-wp
	$(composer) update --working-dir=$< --prefer-dist
	cp -t . $</composer.lock

$(addprefix src/layer-php/,libtidy-0.99.tgz libmcrypt-4.4.8.tgz php-7.3.3.tgz):
	wget --no-verbose --timestamping --directory-prefix=$(@D) https://lambci.s3.amazonaws.com/binaries/$(@F)

url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
#test: start_time = $(shell date '+%F %T')
test:
	curl -f $(url) $(url)home #$(url)license.txt
#	sam logs --name WordPress --stack-name sam-wp --start-time "$(start_time)"
