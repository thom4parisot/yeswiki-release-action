FROM php:7.3-cli-alpine

USER root

RUN apk add --update composer git jq zip npm \
    curl-dev libzip-dev \
    php7-sockets php7-mbstring php7-curl php7-mysqli php7-zip php7-xml && \
  docker-php-ext-configure curl --with-curl=/usr/include && \
  docker-php-ext-configure json && \
  docker-php-ext-configure mbstring && \
  docker-php-ext-configure mysqli && \
  docker-php-ext-configure zip && \
  docker-php-ext-install json mbstring sockets && \
  apk del autoconf g++ libtool make

COPY composer.json /composer.json
COPY composer.lock /composer.lock
#RUN composer install --verbose
RUN composer install --verbose --ignore-platform-req=ext-xml --ignore-platform-req=ext-xml

COPY package.sh /package.sh

CMD [ "/package.sh" ]
