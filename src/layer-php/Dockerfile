# Same version as Lambda execution environment AMI
# This must be nodejs10.x as it's the only environment that's *only* amazon linux 2
FROM lambci/lambda:build-nodejs10.x as build

RUN yum install -y libcurl-devel libxml2-devel libpng-devel libjpeg-turbo-devel openssl-devel

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
RUN install -t /opt/lib /lib64/{libpng15.so.15,libcrypt.so.1,libxml2.so.2,libcurl.so.4}
RUN install -t /opt/lib /lib64/{liblzma.so.5,libnghttp2.so.14,libidn2.so.0,libssh2.so.1,libldap-2.4.so.2,liblber-2.4.so.2}
RUN install -t /opt/lib /lib64/{libunistring.so.0,libsasl2.so.3,libssl3.so,libsmime3.so,libnss3.so}
COPY bootstrap.sh /opt/bootstrap

FROM lambci/lambda:nodejs10.x AS test

COPY --from=build /opt /opt

RUN ldd /opt/bin/php && php -v
RUN ldd /opt/bin/php-cgi && php-cgi -v

FROM lambci/lambda:nodejs10.x

# Layer 1
COPY --from=build /opt /opt
