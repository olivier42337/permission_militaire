FROM php:8.2-fpm

# Installer toutes les dépendances
RUN apt-get update && apt-get install -y \
    nginx gettext git unzip \
    libicu-dev libzip-dev libpq-dev libxml2-dev libonig-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
 && docker-php-ext-configure intl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) intl opcache pdo pdo_mysql zip gd xml mbstring \
 && rm -rf /var/lib/apt/lists/*

# Installer Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Étape 1: Copier SEULEMENT composer.json et installer
WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader

# Étape 2: Copier tout le reste
COPY . .

# Nettoyer la config nginx par défaut
RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*

# Copier notre config nginx
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Permissions
RUN chown -R www-data:www-data /var/www/project
RUN chmod -R 755 /var/www/project

# Variables d'environnement
ENV APP_ENV=prod
ENV APP_DEBUG=0

CMD ["/usr/local/bin/start.sh"]