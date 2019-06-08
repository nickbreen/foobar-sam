# Same version as Lambda execution environment AMI
FROM lambci/lambda:build-provided as build

ARG php_version
ARG php_src=php-src-php-${php_version}.tar.gz
ARG php_src_dir=php-src-php-${php_version}
ADD ${php_src} /usr/local/src
WORKDIR /usr/local/src/${php_src_dir}
RUN ./buildconf --force
RUN ./configure --enable-option-checking=fatal \
        --with-openssl --with-curl --with-zlib --without-pear --disable-phar \
        --with-mhash --enable-mbstring --enable-mysqlnd \
        --with-mysqli --enable-exif --enable-filter --enable-fileinfo --enable-xml --with-gd --enable-xmlreader
RUN make -j install

RUN mkdir -p /opt/{bin,lib}
RUN install -t /opt/bin /usr/local/bin/{php,php-cgi}
COPY bootstrap.sh /opt/bootstrap

RUN /opt/bin/php -v

FROM lambci/lambda:provided

# Layer 1
COPY --from=build /opt /opt
