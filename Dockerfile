FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip sqlite3
RUN docker-php-ext-install pdo pdo_sqlite
RUN rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY . .
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env
RUN echo "MESSENGER_TRANSPORT_DSN=doctrine://default" >> .env
RUN echo "APP_SECRET=12345678901234567890123456789012" >> .env
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
RUN mkdir -p var/cache var/log var/sessions public/build
RUN chmod -R 777 var/
RUN touch var/data.db
RUN echo '{"entrypoints":{"app":{"js":[],"css":[]}}}' > public/build/entrypoints.json
RUN echo '{}' > public/build/manifest.json
CMD php -S 0.0.0.0:10000 -t public
