#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "$0")/lib.sh"

NODE_TCP='const [h, p] = process.argv.slice(1); const s = require("net").connect(+p, h);
s.setTimeout(3000); s.on("connect", () => process.exit(0)); s.on("timeout", () => process.exit(1)); s.on("error", () => process.exit(1));'
PY_TCP='import socket, sys; socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=3)'
NODE_DNS='require("dns").lookup(process.argv[1], (e) => process.exit(e ? 1 : 0))'

from_frontend() { remote "$APP_IP" sudo docker exec ruo-frontend-1 node -e "$NODE_TCP" "$1" "$2"; }
from_backend()  { remote "$APP_IP" sudo docker exec ruo-backend-1 python -c "$PY_TCP" "$1" "$2"; }

title "Izvana (WSL = \"internet\" ovog laba)"
check "WSL -> vm-app:80    frontend (objavljen port)" allowed tcp "$APP_IP" 80
check "WSL -> vm-app:8000  port backenda" blocked tcp "$APP_IP" 8000
check "WSL -> vm-app:5432  port baze" blocked tcp "$APP_IP" 5432
check "WSL -> direktno na backend kontejner" blocked tcp "$(dig_short "backend.$ZONE")" 8000
check "WSL -> direktno na db kontejner" blocked tcp "$(dig_short "db.$ZONE")" 5432

title "Između slojeva (unutar vm-app)"
check "frontend -> backend.$ZONE:8000" allowed from_frontend "backend.$ZONE" 8000
check "frontend razrješava db.$ZONE (DNS radi...)" allowed \
  remote "$APP_IP" sudo docker exec ruo-frontend-1 node -e "$NODE_DNS" "db.$ZONE"
check "frontend -> db.$ZONE:5432 (...ali nema mrežnog puta)" blocked from_frontend "db.$ZONE" 5432
check "backend  -> db.$ZONE:5432" allowed from_backend "db.$ZONE" 5432
check "db       -> internet (segment db je internal)" blocked \
  remote "$APP_IP" sudo docker exec ruo-db-1 wget -q -T 3 -O /dev/null http://example.com/

finish