FROM php:8.2-fpm

RUN apt-get update && apt-get install -y nginx git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction

RUN echo '[global]' > /usr/local/etc/php-fpm.conf && \
    echo 'daemonize = no' >> /usr/local/etc/php-fpm.conf && \
    echo '[www]' >> /usr/local/etc/php-fpm.conf && \
    echo 'listen = 9000' >> /usr/local/etc/php-fpm.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]