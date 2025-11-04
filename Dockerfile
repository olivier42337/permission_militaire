FROM php:8.2-cli

RUN apt-get update && apt-get install -y git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY . .

RUN echo "APP_ENV=prod" > .env && \
    echo "APP_DEBUG=0" >> .env

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# ✅ CRÉER LES FICHIERS WEBPACK VIDES
RUN mkdir -p public/build && \
    echo '{"entrypoints":{},"integrity":{}}' > public/build/entrypoints.json && \
    echo '{}' > public/build/manifest.json

CMD ["php", "-S", "0.0.0.0:10000", "-t", "public"]