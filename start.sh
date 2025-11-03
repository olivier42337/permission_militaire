#!/usr/bin/env sh
set -e

# Rendre la conf Nginx depuis le template (avec ${PORT} injecté par Render)
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Lancer php-fpm en arrière-plan puis nginx au premier plan
php-fpm -D
exec nginx -g 'daemon off;'
