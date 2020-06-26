#!/bin/sh

cat <<EOF >>$PGDATA/postgresql.conf
log_statement = 'all'
log_connections = on
log_disconnections = on
EOF
