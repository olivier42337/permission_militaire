FROM webdevops/php-nginx:8.2

# Dossier de travail
WORKDIR /var/www/project

# Copier les fichiers
COPY . .

# Créer la structure de dossiers
RUN mkdir -p var/cache var/log

# Permissions
RUN chmod -R 755 var/

# L'image a déjà Composer et les dépendances de base