# OrdreFlow Hosting

- [`docker/local/README.md`](docker/local/README.md) describes the local Docker Compose setup and its demo logins.
- [`terraform/environments/test/README.md`](terraform/environments/test/README.md) describes the disposable Hetzner Cloud test deployment with Cloudflare DNS and HTTPS.

## Local infrastructure tools

This repository's Flox environment declares Terraform, curl, jq, and OpenSSH. Install Flox, authenticate with FloxHub if package resolution requests it, then run `flox activate` from the repository root. Flox generates `.flox/env/manifest.lock` when it resolves the packages; commit that lock file alongside changes to `manifest.toml`.

The Docker CLI/daemon used by `docker/local` is installed on the host, not provided by this Flox environment.
