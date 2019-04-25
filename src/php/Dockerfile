FROM lambci/lambda:build

ADD brew-2.1.1.tar.gz /usr/local/lib

RUN eval $(/usr/local/lib/brew-2.1.1/bin/brew shellenv); brew install mawk php
