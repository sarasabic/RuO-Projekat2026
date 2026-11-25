#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "$0")/lib.sh"
KEY="$(dirname "$0")/../.secrets/tf-key.key"
REVERSE_ZONE="$(echo "$DNS_IP" | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')"

title "AO-7: zapisi koje daje BIND na vm-dns ($DNS_IP), zona $ZONE"
for name in ns1 vm-app vm-dns frontend backend db; do
  printf '  %-30s A      %s\n' "$name.$ZONE" "$(dig_short "$name.$ZONE")"
done
printf '  %-30s CNAME  %s\n' "www.$ZONE" "$(dig_short "www.$ZONE" CNAME)"
printf '  %-30s NS     %s\n' "$ZONE" "$(dig_short "$ZONE" NS)"
printf '  %-30s SOA    %s\n' "$ZONE" "$(dig_short "$ZONE" SOA)"
for ip in "$APP_IP" "$DNS_IP"; do
  printf '  %-30s PTR    %s\n' "$ip" "$(dig +short @"$DNS_IP" -x "$ip")"
done

title "DNS odgovori odgovaraju stvarnim adresama"
expect "vm-app.$ZONE = Terraform output" "$APP_IP" "$(dig_short "vm-app.$ZONE")"
expect "vm-dns.$ZONE = Terraform output" "$DNS_IP" "$(dig_short "vm-dns.$ZONE")"

for pair in frontend:web backend:app db:db; do
  svc="${pair%%:*}"; net="ruo_${pair##*:}"
  real="$(remote "$APP_IP" sudo docker inspect -f "{{(index .NetworkSettings.Networks \"$net\").IPAddress}}" "ruo-$svc-1")"
  expect "$svc.$ZONE = adresa kontejnera" "$real" "$(dig_short "$svc.$ZONE")"
done

title "Kontejneri razrješavaju imena preko našeg BIND-a"
expect "frontend razrješava backend.$ZONE" "$(dig_short "backend.$ZONE")" \
  "$(remote "$APP_IP" sudo docker exec ruo-frontend-1 node -e \
     'require("dns").lookup(process.argv[1], (e, a) => console.log(e ? "ERROR" : a))' "backend.$ZONE")"
expect "backend razrješava db.$ZONE" "$(dig_short "db.$ZONE")" \
  "$(remote "$APP_IP" sudo docker exec ruo-backend-1 python -c \
     'import socket, sys; print(socket.gethostbyname(sys.argv[1]))' "db.$ZONE")"

title "Server je isključivo autoritativan"
expect "upit za tuđi domen (example.com)" "REFUSED" \
  "$(dig @"$DNS_IP" example.com A | grep -o 'status: [A-Z]*' | cut -d' ' -f2)"
check "prenos zone (AXFR) za $ZONE" blocked bash -c "dig @$DNS_IP $ZONE AXFR | grep -q SOA"

title "AO-8: TSIG ključ smije mijenjati SAMO zonu projekta"
check "tf-key: dodaj TXT zapis u $ZONE" allowed nsupdate -k "$KEY" <<EOF
server $DNS_IP
zone $ZONE
update add tsig-test.$ZONE 60 TXT "tests/dns.sh"
send
EOF
# test zapis se odmah brise, da zona ostane onakva kakvu je napravio Terraform
nsupdate -k "$KEY" <<EOF >/dev/null 2>&1
server $DNS_IP
zone $ZONE
update delete tsig-test.$ZONE TXT
send
EOF
check "tf-key: dodaj PTR zapis u $REVERSE_ZONE" blocked nsupdate -k "$KEY" <<EOF
server $DNS_IP
zone $REVERSE_ZONE
update add 99.$REVERSE_ZONE 60 PTR hacked.$ZONE.
send
EOF

finish