FROM php:8.2-fpm

# Dépendances système + extensions PHP utiles Symfony
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

# Meilleur cache build: installer les vendors sans scripts
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts

# Copier le reste de l’app
COPY . .

# Créer/autoriser le cache/logs Symfony
RUN mkdir -p var/cache var/log \
 && chown -R www-data:www-data /var/www/project \
 && chmod -R 775 var

# Nginx: supprimer toute conf par défaut (évite listen 80/443)
RUN rm -f /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* \
 && mkdir -p /var/log/nginx

# Conf templatisée + script de démarrage
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Prod
ENV APP_ENV=prod APP_DEBUG=0

# Important: ne pas EXPOSE 80/443; Render fournit ${PORT}
CMD ["/usr/local/bin/start.sh"]
