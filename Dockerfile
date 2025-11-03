FROM webdevops/php-nginx:8.2

# Installation des extensions supplémentaires si nécessaire
RUN docker-php-ext-install pdo pdo_mysql gd

# Dossier de travail
WORKDIR /var/www/project

# Copier les fichiers
COPY . .

# Créer la structure de dossiers
RUN mkdir -p var/cache var/log

# Installer les dépendances
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Permissions
RUN chmod -R 755 var/

# Port (utilise le port par défaut de l'image)
EXPOSE 80

# L'image a déjà Nginx et PHP-FPM configurés