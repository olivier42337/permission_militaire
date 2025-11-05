FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip sqlite3
RUN docker-php-ext-install pdo pdo_sqlite
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY . .
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env
RUN echo "DATABASE_URL=sqlite:////app/var/data.db" >> .env
RUN composer install --no-dev --no-interaction
RUN mkdir -p var && chmod 777 var
CMD php -S 0.0.0.0:10000 -t public
