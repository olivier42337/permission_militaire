FROM php:8.2-fpm

# Mise à jour et installation des packages essentiels seulement
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
    supervisor

# Installer seulement les extensions ESSENTIELLES
RUN docker-php-ext-install pdo pdo_mysql mbstring bcmath gd

# Installer Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Créer le dossier de travail et structure
WORKDIR /var/www/project
RUN mkdir -p var/cache var/log public

# Copier les fichiers
COPY . .

# Installer les dépendances
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Copier les configurations
COPY docker/nginx.conf /etc/nginx/sites-available/default
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Lien symbolique pour Nginx
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Configurer les permissions (simplifié)
RUN chmod -R 755 var/ public/

# Nettoyer le cache
RUN php bin/console cache:clear --env=prod --no-debug

# Port exposé
EXPOSE 8000

# Commande de démarrage
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisor.conf"]