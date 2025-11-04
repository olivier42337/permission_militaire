FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
CMD ["php", "-S", "0.0.0.0:10000", "-t", "public"]
