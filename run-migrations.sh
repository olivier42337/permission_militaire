#!/bin/bash
set -e
echo "🔧 Running database migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
echo "🚀 Starting Symfony server..."
php -S 0.0.0.0:10000 -t public
