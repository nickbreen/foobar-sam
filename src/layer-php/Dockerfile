# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

####### PHP custom runtime #######

####### Install and compile everything #######

# Same AL version as Lambda execution environment AMI
FROM amazonlinux:2-with-sources as builder

# Lock to 2017.03 release (same as Lambda) and install compilation dependencies
#RUN sed -i 's;^releasever.*;releasever=2017.03;;' /etc/yum.conf && \
RUN yum clean all && yum install -y autoconf \
        bison \
        gcc \
        gcc-c++ \
        make \
        libcurl-devel \
        libxml2-devel \
        openssl-devel \
        tar \
        gzip \
        zip \
        unzip \
        git

RUN yum install -y libpng-devel lib-jpeg-turbo-devel file diffutils

ARG php_version=7.3.4
ARG php_src=php-src-php-${php_version}.tar.gz
ARG php_src_dir=php-src-php-${php_version}
ADD ${php_src} /opt/src
WORKDIR /opt/src/${php_src_dir}
RUN ./buildconf --force
RUN ./configure --prefix=/opt/ --enable-option-checking=fatal \
        --with-openssl --with-curl --with-zlib --without-pear --disable-phar \
        --with-mhash --enable-mbstring --enable-mysqlnd \
        --with-mysqli --enable-exif --enable-filter --enable-fileinfo --enable-xml --with-gd --enable-xmlreader
#RUN make -j test
RUN make -j install
RUN /opt/bin/php -v
RUN /opt/bin/php-cgi -v

# Prepare runtime files
RUN mkdir -p /lambda-php-runtime/bin && cp /opt/bin/{php,php-cgi} /lambda-php-runtime/bin/
RUN mkdir -p /lambda-php-runtime/etc && cp /opt/src/${php_src_dir}/php.ini-production /lambda-php-runtime/etc/php.ini

RUN find  /lambda-php-runtime

ARG bootstrap=bootstrap.sh
COPY ${bootstrap} /lambda-php-runtime/bootstrap

###### Create runtime image ######

FROM lambci/lambda:provided as runtime

# Layer 1
COPY --from=builder /lambda-php-runtime /opt/

###### Create function image ######

FROM runtime as function

ARG handler=handler.sh
COPY ${hander} /var/task/
WORKDIR /var/task/

