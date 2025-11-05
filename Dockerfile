FROM php:8.2-cli

RUN apt-get update && apt-get install -y git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY . .

RUN echo "APP_ENV=dev" > .env
RUN echo "APP_DEBUG=1" >> .env
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env

RUN mkdir -p var/cache var/log public/build
RUN chmod -R 777 var/

RUN echo '{"entrypoints":{},"integrity":{}}' > public/build/entrypoints.json
RUN echo '{}' > public/build/manifest.json

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

CMD ["php", "-d", "display_errors=1", "-S", "0.0.0.0:10000", "-t", "public"]