FROM php:8.2-fpm

# Installer nginx et envsubst
RUN apt-get update && apt-get install -y nginx gettext

# Copier le template nginx
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Copier le code de l'application
COPY . /var/www/project
WORKDIR /var/www/project

# Script de démarrage qui processe le template
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]