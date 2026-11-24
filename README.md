# OrdreFlow Hosting

- [`docker/local/README.md`](docker/local/README.md) describes the local Docker Compose setup and its demo logins.
- [`docker/mvp/README.md`](docker/mvp/README.md) runs the public `:mvp` images in a separate local Docker Compose stack.
- [`terraform/environments/test/README.md`](terraform/environments/test/README.md) describes the disposable Hetzner Cloud test deployment with Cloudflare DNS and HTTPS.
- [`k8s/README.md`](k8s/README.md) describes the dev K3s + Flux GitOps profile and the local k3d profile; [`terraform/environments/k3s-test/README.md`](terraform/environments/k3s-test/README.md) provisions the dev server.

## Local infrastructure tools

This repository's Flox environment declares Terraform, curl, jq, OpenSSH, Docker CLI, OpenSSL, k3d, kubectl, Kustomize, and Flux CLI. Install Flox, authenticate with FloxHub if package resolution requests it, then run `flox activate` from the repository root. Flox generates `.flox/env/manifest.lock` when it resolves the packages; commit that lock file alongside changes to `manifest.toml`.

Flox supplies the Docker CLI; a running Docker daemon is still required on the host for `docker/local`, `docker/mvp`, and k3d.
