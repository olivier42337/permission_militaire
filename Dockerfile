FROM php:8.2-fpm

RUN apt-get update && apt-get install -y nginx
WORKDIR /var/www/project
COPY . .
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Vérifier que public/index.php existe
RUN ls -la public/index.php || echo "⚠️ index.php missing"

CMD ["/start.sh"]