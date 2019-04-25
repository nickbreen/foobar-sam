FROM lambci/lambda:build

ADD brew-2.1.1.tar.gz /opt

RUN eval $(/opt/brew-2.1.1/bin/brew shellenv); brew install mawk php
