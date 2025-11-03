#!/usr/bin/env sh
set -e

# Rendre la conf Nginx (Render injecte ${PORT})
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Lancer PHP-FPM en arrière-plan
php-fpm -D

# Préparer le cache en prod (sans bloquer si DB non joignable)
php -d detect_unicode=0 bin/console cache:clear --env=prod --no-warmup || true
php -d detect_unicode=0 bin/console cache:warmup --env=prod || true

# Nginx au premier plan
exec nginx -g 'daemon off;'
