#!/bin/bash
set -e
php-fpm -D
nginx -g 'daemon off;'
