# OrdreFlow Kubernetes profiles

The shared manifests are in [`apps/ordreflow`](apps/ordreflow). The [dev overlay](overlays/dev/kustomization.yaml) runs on a single-node K3s server provisioned by [Terraform](../terraform/environments/k3s-test/README.md); Flux watches this repository's `main` branch at `k8s/clusters/test` and installs cert-manager, Let's Encrypt, and OrdreFlow. The [local overlay](overlays/local/README.md) uses locally built images in k3d, with no Flux installation. Both use K3s Traefik and local-path storage. The dev cluster is separate from `docker/local`, `docker/mvp`, and the Compose VPS.

## Prepare the Git repository

1. Set `APP_HOST` in [`clusters/test/app.yaml`](clusters/test/app.yaml) to the hostname in your K3s Terraform variables. Set `ACME_EMAIL` in [`clusters/test/issuer.yaml`](clusters/test/issuer.yaml) to your certificate contact address. Commit and merge these manifests to `main` before bootstrapping Flux.
2. After a successful CI run on `dev`, the backend and frontend workflows replace their respective `:dev` images in GHCR (`main` still publishes `:main`). The backend pushes API before migrations, so Flux watches the **migrations `:dev` digest** as the backend release signal. When it changes, Flux updates an annotation on the API pod template in Git. This restarts the API's single replica and its migration init container; both use `imagePullPolicy: Always` to pull the new `:dev` images. The frontend's `:dev` digest drives its own rollout. The scanner does not need a separate API ImageRepository because it uses the last-pushed migrations image as the backend release signal.
3. GHCR `:dev` images currently reject anonymous pulls. Create a `ghcr-pull` registry secret in both `ordreflow` (pod pulls) and `flux-system` (Flux image scanning). Use a GitHub credential with `read:packages` and access to all three packages.

## Bootstrap after Terraform apply

The server's port 6443 is not exposed. From your workstation, use an SSH tunnel to reach the Kubernetes API, and copy the kubeconfig with restrictive permissions:

```sh
SERVER_IP="$(terraform -chdir=terraform/environments/k3s-test output -raw server_ipv4)"
mkdir -p "$HOME/.kube"
umask 077
ssh -i "$HOME/.ssh/ordreflow-test" "root@$SERVER_IP" 'cat /etc/rancher/k3s/k3s.yaml' > "$HOME/.kube/ordreflow-k3s-test"
export KUBECONFIG="$HOME/.kube/ordreflow-k3s-test"
ssh -i "$HOME/.ssh/ordreflow-test" -N -L 6443:127.0.0.1:6443 "root@$SERVER_IP"
```

Keep the tunnel running in a separate terminal while using `kubectl` or `flux`. The kubeconfig grants cluster-admin access; keep it on your workstation and out of Git. Check with `kubectl get nodes`.

Create the namespace and the application secret *before* bootstrapping the workloads. Use an administrator email and a password that meets ASP.NET Identity's password policy:

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
```

Record the credentials somewhere recoverable; the local-path PostgreSQL volume lives on this one VPS and is removed with the server. Demo employees are not automatically seeded in K3s: the API bootstraps the administrator account from this secret.

Create the registry credentials before Flux starts scanning. `GHCR_USER` is the account with access to the packages; enter its package-read token when prompted (input is not echoed):

```sh
read -rp 'GHCR username: ' GHCR_USER
read -rsp 'GHCR package-read token: ' GHCR_TOKEN; echo
kubectl create namespace flux-system
for NS in ordreflow flux-system; do
  kubectl -n "$NS" create secret docker-registry ghcr-pull \
    --docker-server=ghcr.io --docker-username="$GHCR_USER" --docker-password="$GHCR_TOKEN"
done
unset GHCR_TOKEN GHCR_USER
```

With the Flux CLI installed locally, set `GITHUB_TOKEN` to a token authorized to create a write-enabled deploy key for `ordreflow/ordreflow-hosting`, then run:

```sh
flux bootstrap github \
  --owner=ordreflow \
  --repository=ordreflow-hosting \
  --branch=main \
  --path=k8s/clusters/test \
  --read-write-key=true \
  --components-extra=image-reflector-controller,image-automation-controller
flux get kustomizations
flux get images all
kubectl -n ordreflow get pods,ingress
```

Bootstrap commits generated files under `k8s/clusters/test/flux-system/`; pull that commit locally. The GitHub deploy key needs write access to `main` for image automation (including any applicable branch rules). The GitHub token is used only for bootstrap; it is not put into Terraform state or the application manifests. Flux checks the `:dev` digests every minute and commits digest changes to the [dev overlay](overlays/dev/kustomization.yaml) release annotations, then reconciles that Git commit. The workload images remain tagged `:dev`; the digest annotations trigger a fresh pull and rollout. Local image builds and imports never update the dev overlay. Check `https://<APP_HOST>/api/health` once DNS and TLS are ready.

For debugging, use `flux get all -A`, `flux get images all`, `kubectl -n ordreflow describe pod <name>`, and `kubectl -n ordreflow logs deployment/api -c migrate`. The API pod runs `dotnet ef database update` once on each startup, which is idempotent for an already-migrated database. This single-node test stack has no automatic database backup; back up PostgreSQL before replacing the server.
