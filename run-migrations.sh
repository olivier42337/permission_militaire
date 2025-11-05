#!/bin/bash
set -e

echo "🔧 Vérification de la base de données..."

# Définir MESSENGER_TRANSPORT_DSN pour les migrations
export MESSENGER_TRANSPORT_DSN=doctrine://default

php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

echo "🚀 Démarrage du serveur Symfony..."
php -S 0.0.0.0:10000 -t public
