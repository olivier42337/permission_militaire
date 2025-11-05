FROM php:8.2-cli
RUN apt-get update && apt-get install -y --no-install-recommends git unzip sqlite3 libsqlite3-dev
RUN docker-php-ext-install pdo pdo_sqlite
RUN rm -rf /var/lib/apt/lists/*
ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_MEMORY_LIMIT=-1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts
COPY . .
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env
RUN composer dump-env prod
RUN mkdir -p var/cache var/log var/sessions public/build
RUN touch var/data.db
RUN chmod -R 775 var
RUN [ -f public/build/entrypoints.json ] || printf '{ "entrypoints": { "app": { "js": [], "css": [] } }, "integrity": {} }' > public/build/entrypoints.json
RUN [ -f public/build/manifest.json ]   || printf '{}' > public/build/manifest.json
RUN echo "ok" > public/healthz.html
ENV APP_ENV=prod APP_DEBUG=0 SYMFONY_DEPRECATIONS_HELPER=disabled
CMD sh -c "php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration && php -S 0.0.0.0:${PORT:-10000} -t public"
