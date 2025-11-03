FROM php:8.2-fpm

# Installation des packages
RUN apt-get update && apt-get install -y \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libpq-dev \
    nginx \
    supervisor

# Extensions PHP essentielles
RUN docker-php-ext-install pdo pdo_mysql mbstring gd

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Dossier de travail
WORKDIR /var/www/project

# Copier le code
COPY . .

# Créer la structure de dossiers
RUN mkdir -p var/cache var/log

# Installer les dépendances seulement
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Configuration Nginx
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Configuration Supervisor
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Permissions
RUN chmod -R 755 var/

# Port
EXPOSE 8000

# Commande de démarrage
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisor.conf"]