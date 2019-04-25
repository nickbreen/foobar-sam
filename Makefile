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

php_version = 7.3.4

.PHONY: build clean outdated update test int acc til

build: $(addprefix out/layer-,php wp bootstrap) $(addprefix out/func-,js sh php) FORCE

deploy: out/sam.yaml
	sam deploy --template-file $< --stack-name sam-wp --capabilities CAPABILITY_IAM

out/sam.yaml: src/sam.yaml out/layer-php out/layer-wp out/layer-bootstrap out/func-sh
	sam package --template-file $< --output-template-file $@ --s3-bucket wp.foobar.nz

out/func-php: src/func-php/index.php src/func-php/debug.php
	rm -rf $@; mkdir $@
	cp -t $@ $^

out/func-sh: src/func-sh/*
	rm -rf $@; mkdir $@
	cp -t $@ $^

out/func-js: src/func-js/*
	rm -rf $@; mkdir $@
	cp -t $@ $^
	npm --cache .cache/npm --prefix $@ install --only=production

out/layer-wp: src/layer-wp/*
	rm -rf $@; mkdir $@
	cp -t $@ $^
	$(composer) install --working-dir=$@ --prefer-dist
	$(composer) config --working-dir=$@ version $(version)

out/layer-php: src/layer-php/*
	rm -rf $@; mkdir -p $@/lib
	tar xf src/layer-php/libmcrypt-4.4.8.tgz --directory=$@/lib --strip-components=2
	tar xf src/layer-php/libtidy-0.99.tgz --directory=$@/lib --strip-components=2
	tar xf src/layer-php/php-7.3.3.tgz --directory=$@ --strip-components=1
	cp -r -t $@ src/layer-php/etc

out/layer-bootstrap: src/layer-bootstrap/bootstrap.php FORCE
	rm -rf $@; mkdir -p $@
	cp $< $@/bootstrap
	chmod +x $@/bootstrap

clean:
	rm -rf out/*

outdated: src/layer-wp.outdated src/func-js.outdated

out/layer-wp.outdated: out/layer-wp
	$(composer) outdated --working-dir=$< --direct --strict | tee $@

out/func-js.outdated: out/func-js
	npm outdated --prefix=$< | tee $@

update: out/layer-wp
	$(composer) update --working-dir=$< --prefer-dist
	cp -t . $</composer.lock

$(addprefix src/layer-php/,libtidy-0.99.tgz libmcrypt-4.4.8.tgz php-7.3.3.tgz):
	wget --no-verbose --timestamping --directory-prefix=$(@D) https://lambci.s3.amazonaws.com/binaries/$(@F)

php: out/php-src-php-$(php_version) FORCE
out/php-src-php-$(php_version): src/php/php-src-php-$(php_version).tar.gz src/php/bootstrap.sh
	rm -rf $@; mkdir -p $@
	tar xf $< --directory=$@ --strip-components=1

out/php: src/php/Dockerfile
	rm -rf $@; mkdir -p $@
	docker pull lambda-brew-php || docker build -t lambda-brew-php ${<D}
	docker save --output lambda-brew-php.tar lambda-brew-php
	tar tf lambda-brew-php.tar

#	docker run --rm --tty --workdir /var/task \
#			--env HOMEBREW_CACHE=/opt/.cache \
#			--env HOMEBREW_NO_AUTO_UPDATE=true \
#			--volume $(realpath .cache/brew):/opt/.cache:rw \
#			--volume $(realpath $@):/var/task/brew-2.1.1/Cellar:rw \
#			--volume $(realpath src/php/bootstrap.sh):/opt/bootstrap:ro \
#			--volume $(realpath src/php/brew-2.1.1.tar.gz):/var/task/brew-2.1.1.tar.gz:ro \
#			lambci/lambda:build /opt/bootstrap

src/php/php-src-php-$(php_version).tar.gz:
	rm -rf $@; mkdir -p ${@D}
	wget --no-verbose --timestamping --output-document=${@}\
			https://codeload.github.com/php/php-src/tar.gz/php-$(php_version)

src/php/php-build-php-build-v0.10.0-master.tar.gz:
	mkdir -p ${@D}
	curl -sSfJLR -o ${@} -z${@} https://github.com/php-build/php-build/tarball/master

src/php/brew-2.1.1.tar.gz:
	mkdir -p ${@D}
	curl -sSfJLR -o ${@} -z${@} https://github.com/Homebrew/brew/archive/2.1.1.tar.gz

test: int

int: out/test/int
out/test/int: src/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	sam local generate-event apigateway aws-proxy | tee /dev/stderr |\
			sam local invoke --template src/sam.yaml\
					--docker-volume-basedir src\
					--layer-cache-basedir $@/sam.layer.cache\
					WordPress | tee $@/invoke.out >&2
	jq -r .body < $@/invoke.out

acc: out/test/acc
out/test/acc: src/test src/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -P $(realpath src) -o $@ -t $(realpath src/sam.yaml)

til: url = $(shell aws cloudformation describe-stacks --stack-name sam-wp | \
	jq -r '.Stacks[].Outputs[] | select(.OutputKey == "Endpoint") | .OutputValue')
til: out/test/til
out/test/til: src/test src/sam.yaml build FORCE
	rm -rf $@; mkdir -p $@
	src/test/test.sh -P $(realpath src) -o $@ -t $(realpath src/sam.yaml) -u $(url)

FORCE: