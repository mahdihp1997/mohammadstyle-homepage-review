#!/bin/sh
set -eu
: "${PUBLIC_HOST:?HTTPS hostname required}" "${PUBLIC_ORIGIN:?HTTPS origin required}"
case "$PUBLIC_HOST" in *[!A-Za-z0-9.-]*|'') echo 'Invalid public hostname' >&2; exit 1;; esac
case "$PUBLIC_ORIGIN" in https://*) ;; *) echo 'HTTPS origin required' >&2; exit 1;; esac
mkdir -p /tmp/nginx-client /tmp/nginx-proxy
chown node:node /tmp/nginx-client /tmp/nginx-proxy
envsubst '${PUBLIC_HOST} ${PUBLIC_ORIGIN}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
cat > /etc/nginx/nginx.conf <<'NGINX'
user node;
worker_processes auto;
pid /tmp/nginx.pid;
error_log /dev/stderr crit;
events { worker_connections 1024; }
http {
  default_type application/octet-stream;
  sendfile on;
  keepalive_timeout 65;
  include /etc/nginx/conf.d/*.conf;
}
NGINX
nginx -t
exec nginx -g 'daemon off;'
