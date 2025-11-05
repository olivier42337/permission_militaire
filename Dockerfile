FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip sqlite3
RUN docker-php-ext-install pdo pdo_mysql
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/project
COPY . .
RUN echo "APP_ENV=prod" > .env
RUN echo "APP_DEBUG=0" >> .env
RUN echo "DATABASE_URL=sqlite:///%kernel.project_dir%/var/data.db" >> .env
RUN mkdir -p var/cache var/log public/build && chmod -R 777 var/
RUN touch var/data.db && chmod 666 var/data.db
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
RUN cat > public/build/entrypoints.json << 'EOL'
{
  "entrypoints": {
    "app": {
      "js": ["/build/app.js"],
      "css": ["/build/app.css"]
    }
  },
  "integrity": {}
}
EOL
RUN echo '{"app.js":"app.js","app.css":"app.css"}' > public/build/manifest.json
RUN touch public/build/app.js public/build/app.css
CMD ["php", "-S", "0.0.0.0:10000", "-t", "public"]
