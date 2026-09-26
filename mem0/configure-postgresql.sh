#!/usr/bin/env bash
# Create Mem0's role and databases on the host PostgreSQL 18 cluster that
# Hindsight uses. Needs root: gaperton is NOCREATEDB and pgvector is not a
# trusted extension. Reads the mem0 role's password from stdin (install.sh pipes
# POSTGRES_PASSWORD from mem0/upstream/server/.env). Safe to re-run.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

IFS= read -r password
[[ -n "$password" ]] || { echo "error: no password on stdin" >&2; exit 1; }

runuser -u postgres -- psql --set ON_ERROR_STOP=1 --set password="$password" <<'SQL'
SELECT format('CREATE ROLE mem0 LOGIN PASSWORD %L', :'password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mem0')
\gexec
ALTER ROLE mem0 LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'password';

SELECT 'CREATE DATABASE mem0 OWNER mem0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mem0')
\gexec
SELECT 'CREATE DATABASE mem0_app OWNER mem0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mem0_app')
\gexec

REVOKE CONNECT ON DATABASE mem0, mem0_app FROM PUBLIC;
GRANT CONNECT ON DATABASE mem0, mem0_app TO mem0;
SQL

for db in mem0 mem0_app; do
    runuser -u postgres -- psql --set ON_ERROR_STOP=1 --dbname "$db" <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO mem0;
SQL
done
runuser -u postgres -- psql --set ON_ERROR_STOP=1 --dbname mem0 -c 'CREATE EXTENSION IF NOT EXISTS vector'

printf '%s\n' "PostgreSQL is configured for Mem0."
