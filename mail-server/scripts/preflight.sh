#!/usr/bin/env bash
set -euo pipefail

# Run on the dedicated mail VPS before starting the Compose stack.
# Usage: ./scripts/preflight.sh mail.example.com webmail.example.com

MAIL_HOST=${1:?"Usage: $0 mail-host webmail-host"}
WEBMAIL_HOST=${2:?"Usage: $0 mail-host webmail-host"}

failures=0
warn() { printf 'WARN  %s\n' "$*" >&2; }
pass() { printf 'OK    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; failures=$((failures + 1)); }

for host in "$MAIL_HOST" "$WEBMAIL_HOST"; do
  addresses=$(getent ahostsv4 "$host" | awk 'NR==1 {print $1}')
  [[ -n $addresses ]] && pass "$host resolves to $addresses" || fail "$host has no IPv4 DNS record"
done

public_ip=$(curl --fail --silent --show-error --max-time 10 https://api.ipify.org || true)
if [[ -n $public_ip ]]; then
  pass "public IPv4 is $public_ip"
  mail_ip=$(getent ahostsv4 "$MAIL_HOST" | awk 'NR==1 {print $1}')
  [[ $mail_ip == "$public_ip" ]] && pass "$MAIL_HOST points to this VPS" || warn "$MAIL_HOST points to ${mail_ip:-nothing}, not $public_ip"
  ptr=$(dig +short -x "$public_ip" | sed 's/\.$//' | head -n1)
  [[ $ptr == "$MAIL_HOST" ]] && pass "PTR matches $MAIL_HOST" || fail "PTR is ${ptr:-missing}; it must be $MAIL_HOST"
else
  warn 'Could not determine public IPv4 address'
fi

for port in 25 465 587 993; do
  if ss -lnt "( sport = :$port )" | grep -q LISTEN; then
    fail "TCP port $port is already in use"
  else
    pass "TCP port $port is available"
  fi
done

if timeout 8 bash -c '</dev/tcp/gmail-smtp-in.l.google.com/25' 2>/dev/null; then
  pass 'outbound TCP/25 is reachable'
else
  fail 'outbound TCP/25 is blocked'
fi

if command -v ufw >/dev/null && ufw status | grep -q 'Status: active'; then
  warn 'UFW is active: allow TCP 25, 465, 587 and 993 before launch'
fi

(( failures == 0 )) || { echo "$failures required check(s) failed" >&2; exit 1; }
echo 'Preflight completed successfully.'
