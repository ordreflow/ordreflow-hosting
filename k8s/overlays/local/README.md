# Local Kubernetes profile (k3d)

The [local Kustomize overlay](kustomization.yaml) reuses the OrdreFlow base, replaces the three GHCR references with `ordreflow-*:local` images, and uses HTTP on `localhost:18090`. It does not install Flux, cert-manager, or registry pull credentials. The [dev overlay](../dev/kustomization.yaml) is what the remote Flux cluster deploys.

From the hosting repository root, use `flox activate` for `k3d`, `kubectl`, `kustomize`, Docker CLI, and OpenSSL. The Flox lockfile needs to be resolved after adding these tools; if Flox asks, run `flox auth login` first. A running Docker daemon is also required on the host. The backend/frontend sibling checkouts must be at `../ordreflow-backend` and `../ordreflow-frontend` (adjust the build paths otherwise).

Build the images from those checkouts, create the local cluster, and import the images into K3s's container runtime:

```sh
docker build --target final -t ordreflow-api:local ../ordreflow-backend
docker build --target migration -t ordreflow-migrations:local ../ordreflow-backend
docker build -t ordreflow-frontend:local ../ordreflow-frontend
k3d cluster create ordreflow-local --image rancher/k3s:v1.37.2-k3s1 \
  --servers 1 --agents 0 --port '127.0.0.1:18090:80@loadbalancer' --wait
k3d image import ordreflow-api:local ordreflow-migrations:local ordreflow-frontend:local \
  --cluster ordreflow-local
kubectl config use-context k3d-ordreflow-local
```

Create the application secret once, before deploying the pods. The administrator password must satisfy ASP.NET Identity's password policy:

```sh
kubectl create namespace ordreflow
read -rsp 'Admin password: ' ADMIN_PASSWORD; echo
kubectl -n ordreflow create secret generic ordreflow-secrets \
  --from-literal=DB_PASSWORD="$(openssl rand -hex 32)" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 48)" \
  --from-literal=ADMIN_EMAIL='admin@example.com' \
  --from-literal=ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  --from-literal=ADMIN_NAME='Administrator'
unset ADMIN_PASSWORD
kubectl apply -k k8s/overlays/local
kubectl -n ordreflow rollout status statefulset/postgres --timeout=5m
kubectl -n ordreflow rollout status deployment/api --timeout=10m
kubectl -n ordreflow rollout status deployment/frontend --timeout=5m
curl --retry 15 --retry-delay 2 --retry-all-errors -fsS http://127.0.0.1:18090/api/health
```

Open `http://127.0.0.1:18090` and log in with the administrator account. Like dev, this profile does not automatically load demo data. The API's init container applies database migrations before it starts.

After rebuilding images, repeat `k3d image import ...` and run `kubectl -n ordreflow rollout restart deployment/api deployment/frontend` to test the new versions. Check `kubectl -n ordreflow logs deployment/api -c migrate` if migrations fail. When finished, run `k3d cluster delete ordreflow-local` (this removes its PostgreSQL data).
