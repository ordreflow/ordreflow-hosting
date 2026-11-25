# Hetzner K3s dev profile

This Terraform root has independent state from [`../test`](../test). `terraform apply` provisions the K3s VPS and DNS, registers a write-enabled GitHub deploy key, installs Flux, creates the application secret in the cluster, and waits for the API and frontend to respond over HTTPS. Flux then watches `k8s/clusters/test` on `main` and automatically deploys changes. The OrdreFlow `:dev` images are publicly pullable from GHCR, so neither Flux nor Kubernetes needs registry credentials.

## One-time inputs

Activate the repository's Flox environment first (`flox activate`); the bootstrap scripts use its Terraform, SSH, and `jq` tools. From the hosting repository root, fill in the example configuration. Use a new DNS-only hostname, a real Let's Encrypt contact address (also used as the initial admin login), and the SSH private key path matching the key registered in Hetzner:

```sh
cp terraform/environments/k3s-test/terraform.tfvars.example terraform/environments/k3s-test/terraform.tfvars
```

Export these credentials in the same shell before `terraform apply`:

```sh
export HCLOUD_TOKEN='your-hetzner-token'
export CLOUDFLARE_API_TOKEN='your-cloudflare-token'
export GITHUB_TOKEN='github-token-allowed-to-manage-deploy-keys'
```

The GitHub token is needed **only during Terraform operations** to register/manage the write-enabled deploy key for `ordreflow/ordreflow-hosting`. Reading this public repo and pulling its public GHCR images needs no token. The token comes from the environment, not `terraform.tfvars` or cloud-init; Terraform state contains only the deploy key's public half. The server generates the application credentials and stores the Flux private key and Kubernetes secret. Your workstation needs SSH access to the VPS to complete apply; Kubernetes port 6443 remains closed to the internet. If you previously set `ghcr_username` in your ignored `terraform.tfvars`, remove that obsolete entry.

The updated GitOps files under `k8s/` must be on `main` before applying. If `main` is protected, its rules must permit commits by the write-enabled deploy key for Flux image automation.

If the K3s server already exists, use **the same Terraform state** that created it. Check `terraform -chdir=terraform/environments/k3s-test state list` before applying; it should include `hcloud_server.k3s`. An empty state means Terraform would try to create a second server rather than finish bootstrapping the existing one. If you have an older `terraform.tfstate.backup`, verify which server is currently in Hetzner before restoring or importing state. If SSH reports a changed host key, verify the server's fingerprint in the Hetzner console before updating your local `known_hosts`; the bootstrap will not bypass SSH host verification.

## Apply

```sh
terraform -chdir=terraform/environments/k3s-test init
terraform -chdir=terraform/environments/k3s-test validate
terraform -chdir=terraform/environments/k3s-test apply
terraform -chdir=terraform/environments/k3s-test output -raw url
```

The first apply can take several minutes while K3s, cert-manager, Flux, the application, and TLS become ready. A later apply also bootstraps an existing K3s server created with the older Terraform configuration; the server's cloud-init is unchanged, so it does not need to be recreated. The deploy key's **public** half is the only part stored in Terraform state.

On a new database, the API creates an administrator account for `acme_email`. Terraform generates its password on the VPS at first bootstrap. Retrieve it over SSH when you need to log in:

```sh
SERVER_IP="$(terraform -chdir=terraform/environments/k3s-test output -raw server_ipv4)"
ssh -i "$HOME/.ssh/ordreflow-test" "root@$SERVER_IP" 'cat /root/ordreflow/admin-credentials'
```

Adjust the SSH key path if `ssh_private_key_path` differs. On an existing database with an administrator already created, its original password remains unchanged.

If apply cannot complete, check `ssh root@<server-ip> 'cloud-init status --long; k3s kubectl get pods -A; cat /root/ordreflow-bootstrap.log'` and the Terraform error, then rerun `terraform apply` with the same inputs. The separate [local k3d profile](../../../k8s/overlays/local/README.md) does not require Terraform. Destroying this server with `terraform -chdir=terraform/environments/k3s-test destroy` removes its local PostgreSQL volume.
