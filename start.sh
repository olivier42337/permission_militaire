#!/bin/bash
set -e

# Générer la config nginx
envsubst '${PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Démarrer PHP-FPM
php-fpm -D

# Démarrer nginx
nginx -g 'daemon off;'