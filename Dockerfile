FROM php:8.2-fpm

# Mettre à jour et installer les dépendances
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    libpq-dev \
    nginx \
    supervisor \
    && docker-php-ext-configure gd \
    && docker-php-ext-install \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl

# Installer Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Créer le dossier de travail
WORKDIR /var/www/project

# Copier les fichiers
COPY . .

# Installer les dépendances
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Créer le dossier docker et copier les configurations
RUN mkdir -p docker
COPY docker/nginx.conf /etc/nginx/sites-available/default
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Configurer les permissions
RUN chown -R www-data:www-data /var/www/project/var
RUN chmod -R 755 /var/www/project/var

# Installer les assets et nettoyer le cache
RUN php bin/console assets:install public
RUN php bin/console cache:clear --env=prod
RUN php bin/console cache:warmup --env=prod

# Port exposé
EXPOSE 8000

# Commande de démarrage
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisor.conf"]