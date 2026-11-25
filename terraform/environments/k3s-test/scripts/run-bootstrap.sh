#!/usr/bin/env bash
set -euo pipefail

ssh_args=(-i "$SSH_PRIVATE_KEY_PATH" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
scp "${ssh_args[@]}" "$BOOTSTRAP_SCRIPT" "root@$SERVER_IP:/root/ordreflow-bootstrap.sh"

# Only the deploy key's public half enters Terraform state. The GHCR token is
# supplied as an ephemeral variable and sent over SSH stdin, not as an argument.
printf '%s\n' "$GHCR_USERNAME" "$GHCR_TOKEN" "$APP_HOST" "$ACME_EMAIL" |
  ssh "${ssh_args[@]}" "root@$SERVER_IP" \
    'umask 077; bash /root/ordreflow-bootstrap.sh > /root/ordreflow-bootstrap.log 2>&1'
