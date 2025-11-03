FROM php:8.2-fpm

# Dépendances système + extensions PHP utiles à Symfony
RUN apt-get update && apt-get install -y \
    nginx gettext git unzip libicu-dev libzip-dev libpq-dev \
 && docker-php-ext-configure intl \
 && docker-php-ext-install -j$(nproc) intl opcache pdo pdo_mysql zip \
 && rm -rf /var/lib/apt/lists/*

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# App
WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader
COPY . .

# Nginx: supprimer toute conf par défaut (80/443)
RUN rm -f /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*

# Copier le template nginx
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Script de démarrage
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Permissions lisibles par nginx/php
RUN chown -R www-data:www-data /var/www/project && chmod -R 755 /var/www/project

# En prod
ENV APP_ENV=prod APP_DEBUG=0

# Important: ne pas EXPOSE 80/443; Render injecte ${PORT}
CMD ["/usr/local/bin/start.sh"]
