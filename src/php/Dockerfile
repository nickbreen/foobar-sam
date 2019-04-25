FROM lambci/lambda:build

ENV HOMEBREW_NO_AUTO_UPDATE=1

ADD brew-2.1.1.tar.gz /opt

RUN /opt/brew-2.1.1/bin/brew fetch mawk php

RUN /opt/brew-2.1.1/bin/brew install mawk php
