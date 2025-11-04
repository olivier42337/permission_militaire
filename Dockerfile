FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    nginx gettext git unzip \
    libicu-dev libzip-dev libpq-dev libxml2-dev libonig-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
 && docker-php-ext-configure intl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) intl opcache pdo pdo_mysql zip gd xml mbstring \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/project
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader

COPY . .

RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

RUN chown -R www-data:www-data /var/www/project
RUN chmod -R 755 /var/www/project

ENV APP_ENV=prod APP_DEBUG=0
CMD ["/usr/local/bin/start.sh"]
