#!/bin/bash
echo "Starting application setup..."
composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
echo "Setup completed!"