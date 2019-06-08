# Same version as Lambda execution environment AMI
FROM lambci/lambda:build-provided as build

#RUN yum install -y libcurl-devel libxml2-devel libpng-devel libjpeg-turbo-devel openssl-devel openssl

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
RUN install -t /opt/lib /lib64/libcrypto.so.10
#RUN install -t /opt/lib /usr/lib64/{libpng15.so.15,libcrypt.so.1,libxml2.so.2,libcurl.so.4}
#RUN install -t /opt/lib /lib64/{liblzma.so.5,libnghttp2.so.14,libidn2.so.0,libssh2.so.1,libldap-2.4.so.2,liblber-2.4.so.2}
#RUN install -t /opt/lib /lib64/{libunistring.so.0,libsasl2.so.3,libssl3.so,libsmime3.so,libnss3.so}
COPY bootstrap.sh /opt/bootstrap

#RUN find $(echo ${LD_LIBRARY_PATH} | tr : ' ') -name libssl.so\* -type f

RUN objdump -p /opt/bin/php | awk -F '[[:space:]]+' '/NEEDED/ { print $NF }' \
        | xargs -r -l -i find $(echo ${LD_LIBRARY_PATH} | tr : ' ') -name '{}' -print -quit \
        | xargs -r install -vt /opt/lib

RUN /opt/bin/php -v

FROM lambci/lambda:provided AS test

COPY --from=build /opt /opt
COPY --from=build /usr/lib64/libssl.so.1.0.2k /opt/lib
#RUN find $(echo ${LD_LIBRARY_PATH} | tr : ' ') -name libssl.so\* -type f
RUN ldd /opt/bin/php; php -v
RUN ldd /opt/bin/php-cgi; php-cgi -v

FROM lambci/lambda:provided

# Layer 1
COPY --from=build /opt /opt
