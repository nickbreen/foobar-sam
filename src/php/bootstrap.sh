#!/bin/sh

set -veo pipefail

tar xf brew-2.1.1.tar.gz
eval $(brew-2.1.1/bin/brew shellenv)

brew --prefix php
brew --cellar php

brew install mawk php


#
#declare tgz php_version prefix
#
#
#mkdir php-build
#tar xf php-build-php-build-v0.10.0-master.tar.gz --strip-components 1 --directory php-build
#./install.sh
#
#
#yum install -y libtidy-devel
#
#yum install -y bzip2-devel libc-client-devel curl-devel freetype-devel gmp-devel libjpeg-devel krb5-devel libmcrypt-devel libpng-devel openssl-devel t1lib-devel mhash-devel
#
#php-build ${php_version} ${prefix}
#
