FROM lambci/lambda:build

ENV HOMEBREW_NO_AUTO_UPDATE=1

ADD brew-2.1.1.tar.gz /opt

RUN /opt/brew-2.1.1/bin/brew fetch --deps mawk
RUN /opt/brew-2.1.1/bin/brew fetch --deps php

RUN eval $(/opt/brew-2.1.1/bin/brew shellenv); /opt/brew-2.1.1/bin/brew install mawk php
