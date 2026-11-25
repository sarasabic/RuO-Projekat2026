#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

title "AO-4: SSH prijava samo ključem"
for vm in "vm-app:$APP_IP" "vm-dns:$DNS_IP"; do
  name="${vm%%:*}"; ip="${vm##*:}"
  check "$name: prijava kao $ADMIN_USER SSH ključem" allowed remote "$ip" true
  
  offered="$(ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o PubkeyAuthentication=no -o PreferredAuthentications=none \
    "$ADMIN_USER@$ip" true 2>&1 | grep -o 'Permission denied ([^)]*)')"
  expect "$name: ponuđeni načini prijave" "Permission denied (publickey)" "$offered"
  expect "$name: sshd PasswordAuthentication" "passwordauthentication no" \
    "$(remote "$ip" sudo sshd -T 2>/dev/null | grep -i '^passwordauthentication')"
done

finish