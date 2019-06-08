FROM lambci/lambda:build-provided as build
RUN yum -C repolist
RUN find $(echo ${LD_LIBRARY_PATH} | tr : ' ') -name libssl.so\* -type f
