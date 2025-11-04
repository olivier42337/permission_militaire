FROM php:8.2-cli

RUN apt-get update && apt-get install -y git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY . .

# FORCER APP_DEBUG=1
RUN echo "APP_ENV=prod" > .env && \
    echo "APP_DEBUG=1" >> .env && \
    echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env

RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

CMD ["php", "-S", "0.0.0.0:10000", "-t", "public"]