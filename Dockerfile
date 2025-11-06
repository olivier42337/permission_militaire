FROM node:20-alpine AS assets
WORKDIR /app
COPY package*.json ./
COPY webpack.config.js ./
RUN npm ci --no-audit --no-fund
COPY assets ./assets
RUN npm run build

FROM php:8.2-cli
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libicu-dev libpq-dev postgresql-client
RUN docker-php-ext-install -j"$(nproc)" intl pdo pdo_pgsql
RUN rm -rf /var/lib/apt/lists/*
ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_MEMORY_LIMIT=-1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts
COPY . .
COPY --from=assets /app/public/build /var/www/project/public/build
RUN rm -f .env .env.local.php
RUN mkdir -p var/cache var/log var/sessions
RUN chmod -R 775 var
RUN echo "ok" > public/healthz.html
ENV APP_ENV=prod APP_DEBUG=0 SYMFONY_DEPRECATIONS_HELPER=disabled
CMD sh -c "php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration || true && php bin/console cache:clear --env=prod || true && php bin/console cache:warmup --env=prod || true && php -S 0.0.0.0:\${PORT:-10000} -t public"
