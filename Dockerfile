FROM php:8.2-fpm

# Paquets système + extensions PHP
RUN apt-get update && apt-get install -y \
    nginx gettext git unzip \
    libicu-dev libzip-dev libpq-dev libxml2-dev libonig-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
 && docker-php-ext-configure intl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" intl opcache pdo pdo_mysql pdo_pgsql zip gd xml mbstring \
 && rm -rf /var/lib/apt/lists/*

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_MEMORY_LIMIT=-1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project

# Copier juste composer.* pour profiter du cache Docker
COPY composer.json composer.lock ./
# build.sh utilisera ces fichiers
COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh
RUN /usr/local/bin/build.sh

# Copier le reste de l'app
COPY . .

# Perms Symfony
RUN mkdir -p var/cache var/log \
 && chown -R www-data:www-data /var/www/project \
 && chmod -R 775 var

# Purger conf Nginx par défaut (évite listen 80/443 résiduels)
RUN rm -f /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* \
 && mkdir -p /var/log/nginx

# Conf Nginx template + script runtime
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Prod
ENV APP_ENV=prod APP_DEBUG=0

# Un seul entrypoint (Render gère ${PORT})
CMD ["/usr/local/bin/start.sh"]
