FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip sqlite3
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY . .
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env
RUN echo "MESSENGER_TRANSPORT_DSN=doctrine://default" >> .env
RUN echo "APP_SECRET=6b3b92c6c261e7d6a3f7b8c9a2d4e5f6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d" >> .env
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env
RUN mkdir -p var/cache var/log var/sessions public/build
RUN touch var/data.db && chmod -R 777 var/
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
RUN echo '{"entrypoints":{"app":{"js":["/build/app.js"],"css":["/build/app.css"]}},"integrity":{}}' > public/build/entrypoints.json
RUN echo '{"app.js":"app.js","app.css":"app.css"}' > public/build/manifest.json
RUN touch public/build/app.js public/build.app.css
CMD sh -c "set -e && echo '🔧 Starting migrations...' && php bin/console doctrine:migrations:migrate --no-interaction && echo '✅ Migrations completed' && echo '🔧 Loading fixtures...' && php bin/console doctrine:fixtures:load --no-interaction --append && echo '✅ Fixtures completed' && echo '🚀 Starting server...' && php -S 0.0.0.0:10000 -t public"
