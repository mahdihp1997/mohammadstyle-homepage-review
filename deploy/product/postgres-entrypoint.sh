#!/bin/sh
set -eu
# PostgreSQL must own a 0600 key. Bind-mounted secrets retain host ownership.
install -d -o postgres -g postgres -m 0700 /var/lib/postgresql/ms-tls
install -o postgres -g postgres -m 0600 /run/secrets/pg_key /var/lib/postgresql/ms-tls/server.key
install -o postgres -g postgres -m 0644 /run/secrets/pg_cert /var/lib/postgresql/ms-tls/server.crt
exec /usr/local/bin/docker-entrypoint.sh postgres \
  -c ssl=on -c ssl_min_protocol_version=TLSv1.2 \
  -c ssl_cert_file=/var/lib/postgresql/ms-tls/server.crt \
  -c ssl_key_file=/var/lib/postgresql/ms-tls/server.key \
  -c hba_file=/opt/ms-pg-hba.conf \
  -c password_encryption=scram-sha-256 \
  -c log_statement=none -c log_min_error_statement=panic -c log_error_verbosity=terse \
  "$@"
