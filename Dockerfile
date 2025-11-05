FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip postgresql-client libpq-dev
RUN docker-php-ext-install pdo pgsql pdo_pgsql
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY . .
RUN echo "APP_ENV=dev" > .env
RUN echo "APP_DEBUG=1" >> .env
RUN echo "DATABASE_URL=postgresql://permission_militaire_user:jkQ9BjS83NzmOytMdRxoyNPug3eOqBoJ@dpg-d45b02re5dus73c0jjcg-a:5432/permission_militaire" >> .env
RUN mkdir -p var/cache var/log public/build && chmod -R 777 var/
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
RUN echo '{"entrypoints":{"app":{"js":["/build/app.js"],"css":["/build/app.css"]}},"integrity":{}}' > public/build/entrypoints.json
RUN echo '{"app.js":"app.js","app.css":"app.css"}' > public/build/manifest.json
RUN touch public/build/app.js public/build/app.css
CMD ["php", "-d", "display_errors=1", "-d", "error_reporting=E_ALL", "-S", "0.0.0.0:10000", "-t", "public"]
