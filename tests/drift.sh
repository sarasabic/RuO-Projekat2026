#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "$0")/lib.sh"
KEY="$(dirname "$0")/../.secrets/tf-key.key"
TF="terraform -chdir=$(dirname "$0")/../terraform/dns"

title "1. Trenutno stanje"
echo "  db.$ZONE -> $(dig_short "db.$ZONE")"

title "2. DRIFT: neko ručno mijenja zapis (nsupdate), mimo koda"
nsupdate -k "$KEY" <<EOF
server $DNS_IP
zone $ZONE
update delete db.$ZONE A
update add db.$ZONE 300 A 10.30.3.99
send
EOF
echo "  db.$ZONE -> $(dig_short "db.$ZONE")   <- aplikacija bi sad tražila bazu na pogrešnom mjestu"

title "3. terraform plan otkriva razliku između koda i stvarnosti"
$TF plan -detailed-exitcode -input=false
rc=$?
expect "izlazni kod plana (2 = ima promjena)" 2 "$rc"

title "4. terraform apply vraća stvarnost na stanje iz koda"
$TF apply -auto-approve -input=false | grep -E 'Apply complete|No changes'
expect "db.$ZONE nakon apply" "10.30.3.10" "$(dig_short "db.$ZONE")"

finish