FROM php:8.2-cli

# Installer PostgreSQL au lieu de MySQL
RUN apt-get update && apt-get install -y git unzip postgresql-client
RUN docker-php-ext-install pdo pdo_pgsql

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY . .

# .env sans DATABASE_URL
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env

RUN mkdir -p var/cache var/log public/build && chmod -R 777 var/

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Webpack
RUN echo '{"entrypoints":{"app":{"js":["/build/app.js"],"css":["/build/app.css"]}},"integrity":{}}' > public/build/entrypoints.json
RUN echo '{"app.js":"app.js","app.css":"app.css"}' > public/build/manifest.json
RUN touch public/build/app.js public/build/app.css

CMD ["php", "-S", "0.0.0.0:10000", "-t", "public"]