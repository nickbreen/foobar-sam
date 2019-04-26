FROM lambci/lambda:build AS build

RUN yum install --assumeyes --downloadonly php71-cli
RUN yum install --assumeyes php71-cli

FROM lambci/lambda:provided

COPY --from=build /usr/bin/php-7.1 /usr/bin/php-cgi-7.1 /opt/bin/
COPY --from=build /usr/lib64/php/7.1 /opt/lib/php/
COPY --from=build /etc/php.ini /etc/php-7.1.ini /opt/etc/
COPY --from=build /etc/php.d /etc/php-7.1.d /opt/etc/php.d/

RUN ldd /opt/bin/php-7.1

RUN find /opt/lib

ENV LD_LIBRARY_PATH=/opt/lib:\${LD_LIBRARY_PATH}

RUN /opt/bin/php-7.1 --version
