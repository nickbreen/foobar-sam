# Same AL version as Lambda execution environment AMI
FROM amazonlinux:2.0.20190508-with-sources as builder

# Lock to release ver same as Lambda and install compilation dependencies
RUN sed -i 's;^releasever.*;releasever=2.0.20190508;;' /etc/yum.conf
RUN yum install -y autoconf \
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
        unzip\
        libpng-devel \
        libjpeg-turbo-devel \
        file \
        diffutils

ARG php_version
ARG php_src=php-src-php-${php_version}.tar.gz
ARG php_src_dir=php-src-php-${php_version}
ADD ${php_src} /opt/src
WORKDIR /opt/src/${php_src_dir}
RUN ./buildconf --force
RUN ./configure --prefix=/opt/php --enable-option-checking=fatal \
        --with-openssl --with-curl --with-zlib --without-pear --disable-phar \
        --with-mhash --enable-mbstring --enable-mysqlnd \
        --with-mysqli --enable-exif --enable-filter --enable-fileinfo --enable-xml --with-gd --enable-xmlreader
#RUN make -j test
RUN make -j install
RUN /opt/php/bin/php -v
RUN /opt/php/bin/php-cgi -v

# Prepare runtime files
RUN mkdir -p /lambda-php-runtime/{bin,etc,lib} \
    && cp /opt/php/bin/{php,php-cgi} /lambda-php-runtime/bin \
    && cp /opt/src/${php_src_dir}/php.ini-production /lambda-php-runtime/etc/php.ini \
    && cp /lib64/libpng15.so.15 /lambda-php-runtime/lib/

ARG bootstrap=bootstrap.sh
COPY ${bootstrap} /lambda-php-runtime/bootstrap

# Create runtime image

FROM amazonlinux:2.0.20190508 AS test

COPY --from=builder /opt/php/bin/php-cgi /opt/bin/
COPY --from=builder /opt/src/${php_src_dir}/php.ini-production /opt/etc/php.ini
COPY --from=builder /lib64/libpng15.so.15 /opt/lib
ENV LD_LIBRARY_PATH=/opt/lib:${LD_LIBRARY_PATH}
RUN ldd /opt/bin/php && /opt/bin/php -v
RUN ldd /opt/bin/php-cgi && /opt/bin/php-cgi -v

FROM scratch AS runtime

# Layer 1
COPY --from=builder /lambda-php-runtime /opt/
