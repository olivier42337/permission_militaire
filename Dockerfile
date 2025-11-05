FROM node:20-alpine AS assets
WORKDIR /app
COPY package*.json webpack.config.js ./
COPY assets ./assets
RUN npm ci --no-audit --no-fund
RUN npm run build

FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip libicu-dev libpq-dev
RUN docker-php-ext-install intl pdo pdo_pgsql
RUN rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
COPY . .
COPY --from=assets /app/public/build ./public/build/
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env
RUN mkdir -p var/cache var/log var/sessions
RUN chmod -R 777 var/
RUN echo "ok" > public/healthz.html
CMD sh -c "php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration && php -S 0.0.0.0:10000 -t public"
