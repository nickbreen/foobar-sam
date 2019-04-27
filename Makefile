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

img2lambda_version = 0.1.1
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

out/layer-php: src/layer-php/linux-amd64-img2lambda src/layer-php/Dockerfile src/layer-php/php-src-php-$(php_version).tar.gz
	rm -rf $@; mkdir -p $@
	docker build --tag ${@F} src/layer-php
	src/layer-php/linux-amd64-img2lambda --image ${@F} --dry-run --output $@
	unzip -l $@/layer-1.zip

src/layer-php/composer.phar:
	curl -fJLR -z ${@} -o ${@} https://getcomposer.org/download/1.8.5/composer.phar \
			-o ${@}.sha256sum https://getcomposer.org/download/1.8.5/composer.phar.sha256sum
	cd ${@D}; sha256sum -c ${@F}.sha256sum
	chmod +x ${@}

out/layer-php/img2lambda: src/layer-php/img2lambda.tar-0.1.0.gz
	rm -rf $@; mkdir -p ${@}
	tar xf $< --directory $@ --strip-components 1
	find $@
	cd $@; ./scripts/build_example.sh

src/layer-php/php-src-php-$(php_version).tar.gz:
	rm -rf $@; mkdir -p ${@D}
	curl -fJLR -z ${@} -o ${@} https://github.com/php/php-src/archive/php-$(php_version).tar.gz

src/layer-php/linux-amd64-img2lambda:
	rm -rf $@; mkdir -p ${@D}
	curl -fJLR -z $@ -o $@ https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(version)/linux-amd64-img2lambda \
		 -z $@.sha256 -o $@.sha256 https://github.com/awslabs/aws-lambda-container-image-converter/releases/download/$(version)/linux-amd64-img2lambda.sha256
	cd ${@D}; sha256sum -c ${@F}.sha256
	chmod +x $@

src/layer-php/img2lambda.tar-0.1.0.gz:
	rm -rf $@; mkdir -p ${@D}
	curl -fJLR -z ${@} -o ${@} https://github.com/awslabs/aws-lambda-container-image-converter/archive/0.1.0.tar.gz

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