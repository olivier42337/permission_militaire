#!/bin/bash

# Substituer la variable PORT dans la config nginx
envsubst '\$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Démarrer PHP-FPM en arrière-plan
php-fpm -D

# Démarrer nginx en premier plan
nginx -g 'daemon off;'