#!/usr/bin/env bash
set -euo pipefail

IFS= read -r app_host
IFS= read -r acme_email

kubectl() { k3s kubectl "$@"; }

for attempt in {1..60}; do
  if kubectl get nodes >/dev/null 2>&1; then break; fi
  if (( attempt == 60 )); then printf 'K3s did not become ready.\n' >&2; exit 1; fi
  sleep 5
done

for namespace in flux-system ordreflow; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl -n flux-system create configmap k3s-test-settings \
  --from-literal=APP_HOST="$app_host" --from-literal=ACME_EMAIL="$acme_email" \
  --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n ordreflow get secret ordreflow-secrets >/dev/null 2>&1; then
  install -d -m 700 /root/ordreflow
  admin_password="Admin$(openssl rand -hex 20)Aa1!"
  db_password="$(openssl rand -hex 32)"
  jwt_secret="$(openssl rand -hex 48)"
  kubectl -n ordreflow create secret generic ordreflow-secrets \
    --from-literal=DB_PASSWORD="$db_password" --from-literal=JWT_SECRET="$jwt_secret" \
    --from-literal=ADMIN_EMAIL="$acme_email" --from-literal=ADMIN_PASSWORD="$admin_password" \
    --from-literal=ADMIN_NAME=Administrator
  umask 077
  printf 'ADMIN_EMAIL=%s\nADMIN_PASSWORD=%s\n' "$acme_email" "$admin_password" > /root/ordreflow/admin-credentials
  unset admin_password db_password jwt_secret
fi

install -d -m 700 /root/.ssh
curl -fsSL https://api.github.com/meta |
  python3 -c 'import json,sys; [print("github.com " + key) for key in json.load(sys.stdin)["ssh_keys"]]' \
  > /root/.ssh/known_hosts
chmod 600 /root/.ssh/known_hosts

if ! command -v flux >/dev/null 2>&1; then
  archive="$(mktemp)"
  arch="$(dpkg --print-architecture)"
  curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v2.9.0/flux_2.9.0_linux_${arch}.tar.gz" -o "$archive"
  tar -xzf "$archive" -C /usr/local/bin flux
  chmod 755 /usr/local/bin/flux
  rm -f "$archive"
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
flux bootstrap git \
  --url=ssh://git@github.com/ordreflow/ordreflow-hosting.git \
  --branch=main --path=k8s/clusters/test \
  --private-key-file=/root/.ssh/flux_deploy_key \
  --components-extra=image-reflector-controller,image-automation-controller \
  --version=v2.9.0 --silent

for attempt in {1..90}; do
  if kubectl -n ordreflow get deployment/api deployment/frontend >/dev/null 2>&1; then break; fi
  if (( attempt == 90 )); then printf 'Flux did not deploy OrdreFlow.\n' >&2; exit 1; fi
  sleep 10
done

kubectl -n ordreflow rollout status statefulset/postgres --timeout=10m
kubectl -n ordreflow rollout status deployment/api --timeout=15m
kubectl -n ordreflow rollout status deployment/frontend --timeout=10m
curl --retry 60 --retry-delay 10 --retry-all-errors --max-time 10 -fsS \
  "https://${app_host}/api/health"
