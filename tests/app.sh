#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "$0")/lib.sh"
URL="http://$APP_IP"
COMPOSE=(sudo docker compose -f /opt/ruo-app/compose.yaml --env-file /etc/ruo-app/app.env)
psql_db() { remote "$APP_IP" sudo docker exec ruo-db-1 psql -U postgres -d quiz -Atc "$1"; }

title "Aplikacija odgovara na $URL"
expect "GET /  HTTP status" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/")"
expect "naslov stranice" "Emoji Movie Quiz" "$(curl -s "$URL/" | grep -o 'Emoji Movie Quiz' | head -1)"
info="$(curl -s "$URL/api/info")"
echo "  GET /api/info   -> $info"
echo "  GET /api/puzzle -> $(curl -s "$URL/api/puzzle")"
expect "backend do baze dolazi DNS imenom" "db.$ZONE" \
  "$(echo "$info" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("db_host"))' 2>/dev/null)"

title "AO-10: podaci preživljavaju ponovno kreiranje kontejnera baze"
player="test-$(date +%H%M%S)"
expect "POST /api/scores ($player)" 201 "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/api/scores" \
  -H 'content-type: application/json' -d "{\"player\": \"$player\", \"points\": 7}")"
old_id="$(remote "$APP_IP" sudo docker inspect -f '{{.Id}}' ruo-db-1 | cut -c1-12)"
echo "  ponovno kreiram db kontejner (docker compose up --force-recreate db)..."
remote "$APP_IP" "${COMPOSE[@]}" up -d --force-recreate --no-deps --wait db >/dev/null 2>&1
new_id="$(remote "$APP_IP" sudo docker inspect -f '{{.Id}}' ruo-db-1 | cut -c1-12)"
echo "  id kontejnera: $old_id -> $new_id"
expect "db kontejner je novi" "yes" "$([ "$old_id" != "$new_id" ] && echo yes || echo no)"
expect "rezultat je i dalje u bazi" 1 "$(psql_db "SELECT count(*) FROM quiz.scores WHERE player = '$player'")"
psql_db "DELETE FROM quiz.scores WHERE player LIKE 'test-%'" >/dev/null   
expect "aplikacija odgovara i nakon toga" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/api/scores")"

finish