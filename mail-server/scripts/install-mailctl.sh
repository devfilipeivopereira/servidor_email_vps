#!/usr/bin/env bash
set -euo pipefail

# Install after completing the Stalwart wizard and creating the least-privilege
# automation account. This script never writes credentials.

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
getent group mailops >/dev/null || groupadd --system mailops
id -u mailops >/dev/null 2>&1 || useradd --system --create-home --gid mailops --shell /bin/bash mailops
install -o root -g root -m 0755 "$SOURCE_DIR/mailctl" /usr/local/sbin/mailctl
install -d -o root -g mailops -m 0750 /etc/mailops /var/log/mailops

if [[ ! -e /etc/mailops/mailctl.env ]]; then
  install -o root -g mailops -m 0640 /dev/null /etc/mailops/mailctl.env
  cat >&2 <<'EOF'
Created /etc/mailops/mailctl.env. Fill it with the Stalwart automation account,
the account domain ID, and a public HTTPS URL such as https://mail.example.com.
Keep its permissions at root:mailops 0640.
EOF
fi

echo 'mailctl installed. Validate with: sudo -u mailops /usr/local/sbin/mailctl list'
