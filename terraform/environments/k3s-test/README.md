# Hetzner K3s dev profile

This Terraform root has independent state and server resources from [`../test`](../test). It creates one Hetzner Cloud VPS for the [dev Kustomize overlay](../../../k8s/overlays/dev/kustomization.yaml), a firewall allowing restricted SSH plus HTTP/HTTPS, and a DNS-only Cloudflare A record. Cloud-init installs pinned K3s with Traefik and local-path storage. The Kubernetes API is reachable only through SSH tunneling. For a laptop-only cluster, follow the [local profile](../../../k8s/overlays/local/README.md); Terraform is not needed there.

From the hosting repository root, copy the example and fill in your real domain, Cloudflare zone ID, Hetzner SSH key name, and current SSH IP:

```sh
cp terraform/environments/k3s-test/terraform.tfvars.example terraform/environments/k3s-test/terraform.tfvars
export HCLOUD_TOKEN='your-hetzner-token'
export CLOUDFLARE_API_TOKEN='your-cloudflare-token'
terraform -chdir=terraform/environments/k3s-test init
terraform -chdir=terraform/environments/k3s-test validate
terraform -chdir=terraform/environments/k3s-test plan
terraform -chdir=terraform/environments/k3s-test apply
terraform -chdir=terraform/environments/k3s-test output -raw server_ipv4
```

Terraform finishes before K3s has necessarily installed. Check readiness via `ssh -i "$HOME/.ssh/ordreflow-test" root@<server-ip> 'cloud-init status --wait && k3s kubectl get nodes'` (adjust the SSH key path). Follow the [GitOps bootstrap instructions](../../../k8s/README.md) to create the application secret and connect Flux to this repository. Terraform does not store the GitHub token, database credentials, or the Kubernetes kubeconfig.

To remove only this test environment, use `terraform -chdir=terraform/environments/k3s-test destroy`. Its PostgreSQL volume is local to the VPS, so destroying the server removes its data.
