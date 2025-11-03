FROM php:8.2-fpm

# Mise à jour et installation des packages en deux étapes
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    libpq-dev

# Installation des extensions PHP séparément
RUN docker-php-ext-install pdo pdo_mysql
RUN docker-php-ext-install mbstring exif pcntl bcmath
RUN docker-php-ext-install zip intl
RUN docker-php-ext-configure gd && docker-php-ext-install gd

# Installation de Nginx et Supervisor séparément
RUN apt-get install -y nginx supervisor

# Installer Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Créer le dossier de travail
WORKDIR /var/www/project

# Copier les fichiers
COPY . .

# Installer les dépendances
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Créer le dossier docker et copier les configurations
RUN mkdir -p /etc/nginx/sites-available
COPY docker/nginx.conf /etc/nginx/sites-available/default
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Lien symbolique pour Nginx
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
RUN rm -f /etc/nginx/sites-enabled/default

# Configurer les permissions
RUN mkdir -p /var/www/project/var
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