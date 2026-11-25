#!/usr/bin/env bash
set -euo pipefail

for attempt in {1..60}; do
  if ssh -i "$SSH_PRIVATE_KEY_PATH" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=10 "root@$SERVER_IP" \
      'cloud-init status --wait >/dev/null && install -d -m 700 /root/.ssh && if [ ! -f /root/.ssh/flux_deploy_key ]; then ssh-keygen -q -t ed25519 -N "" -f /root/.ssh/flux_deploy_key; fi' ; then
    exit 0
  fi
  if (( attempt == 60 )); then break; fi
  sleep 5
done

printf 'Could not prepare a Flux deploy key on the K3s server.\n' >&2
exit 1
