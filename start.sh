#!/bin/bash
set -ex
echo "STARTING NGINX ON PORT 10000"
nginx -t
nginx -g "daemon off; error_log /dev/stderr debug;"
