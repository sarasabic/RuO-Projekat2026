# Zajednicke pomocne funkcije za testove. Ostale skripte ih ucitavaju (source)

: "${APP_IP:?pokreni testove sa 'make test'}" "${DNS_IP:?}" "${ZONE:?}" "${ADMIN_USER:=ruoadmin}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
FAILED=0

title() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

# remote IP naredba: pokrece naredbu na VM-u preko SSH-a (argumenti se sigurno navode sa %q)
remote() { local ip="$1"; shift; ssh "${SSH_OPTS[@]}" "$ADMIN_USER@$ip" "$(printf '%q ' "$@")"; }

# tcp HOST PORT : da li TCP konekcija iz WSL-a uspije u roku od 3 sekunde?
tcp() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

# check "opis" allowed|blocked naredba: pokrece naredbu i poredi rezultat sa ocekivanim
check() {
  local desc="$1" expected="$2" got mark; shift 2
  if "$@" >/dev/null 2>&1; then got=allowed; else got=blocked; fi
  if [ "$got" = "$expected" ]; then mark=$'\033[32mok\033[0m'; else mark=$'\033[31mMISMATCH\033[0m'; FAILED=1; fi
  printf '  %-55s %-8s (očekivano: %-7s) %s\n' "$desc" "$got" "$expected" "$mark"
}

# expect "opis" OCEKIVANO STVARNO: poredi dvije vrijednosti
expect() {
  local desc="$1" expected="$2" actual="$3" mark
  if [ "$expected" = "$actual" ]; then mark=$'\033[32mok\033[0m'; else mark=$'\033[31mMISMATCH\033[0m'; FAILED=1; fi
  printf '  %-42s %-30s (očekivano: %s) %s\n' "$desc" "$actual" "$expected" "$mark"
}

dig_short() { dig +short @"$DNS_IP" "$1" "${2:-A}"; }

finish() { exit "$FAILED"; }