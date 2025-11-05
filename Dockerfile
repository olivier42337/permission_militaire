FROM php:8.2-cli

RUN apt-get update && apt-get install -y git unzip postgresql-client libicu-dev libpq-dev
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl pdo pdo_pgsql
RUN rm -rf /var/lib/apt/lists/*

ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts
COPY . .
RUN composer dump-env prod
RUN mkdir -p var/cache var/log var/sessions public/build
RUN chmod -R 775 var
RUN echo '{"entrypoints":{"app":{"js":[],"css":[]}},"integrity":{}}' > public/build/entrypoints.json
RUN echo '{}' > public/build/manifest.json
RUN echo "ok" > public/healthz.html

ENV APP_ENV=prod APP_DEBUG=0
CMD sh -c "php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration && php -S 0.0.0.0:\${PORT:-10000} -t public"
