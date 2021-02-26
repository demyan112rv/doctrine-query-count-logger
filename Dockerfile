FROM php:7.3-fpm

RUN apt-get update -y
RUN apt-get install -y --no-install-recommends git

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/doctrine-query-count-logger