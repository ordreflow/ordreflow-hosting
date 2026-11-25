#!/usr/bin/env bash
set -euo pipefail

read -r query
server_ip=$(jq -er '.server_ip' <<< "$query")
ssh_private_key_path=$(jq -er '.ssh_private_key_path' <<< "$query")
public_key=$(ssh -i "$ssh_private_key_path" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 "root@$server_ip" 'cat /root/.ssh/flux_deploy_key.pub')
jq -cn --arg public_key "$public_key" '{public_key: $public_key}'
