#!/bin/sh

# Izvršava se JEDNOM: postgres slika izvršava /docker-entrypoint-initdb.d/* samo kada je prazan.
# Uloge -least privilege:
#   quiz_owner – vlasnik baze podataka, sheme i tabela, ali se ne može log inovati
#   quiz_app – iz backenda: može samo čitati filmove, te čitati i unositi rezultate
# Lozinka se preuzima iz varijable okruženja (APP_DB_PASSWORD), a ne iz ove datoteke

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
     -v app_password="$APP_DB_PASSWORD" <<'EOSQL'
CREATE ROLE quiz_owner NOLOGIN;
CREATE ROLE quiz_app LOGIN PASSWORD :'app_password' CONNECTION LIMIT 20;

CREATE DATABASE quiz OWNER quiz_owner;
REVOKE ALL ON DATABASE quiz FROM PUBLIC;      -- zabrana
GRANT CONNECT ON DATABASE quiz TO quiz_app;
EOSQL