# Disposable test environment

Follow this guide from a Linux terminal (or Ubuntu in WSL). Terraform creates an Ubuntu VPS and firewall in Hetzner Cloud and a DNS record in Cloudflare. The VPS starts PostgreSQL, migrations, the [demo SQL](../../../docker/local/seed-demo.sql), the API, frontend, and HTTPS proxy automatically. You do **not** create the VPS, firewall, or DNS record by hand.

Choose **one person to run Terraform** for this test deployment. Terraform keeps a local state file that records what it created; another group member running `apply` from a different clone without that state could try to create a second server. Everyone can use the web app without SSH access.

## 1. Prepare your tools

Install [Flox](https://flox.dev/docs/install-flox/install/) on Linux/WSL. From the **repository root**, run:

```bash
flox activate
terraform version
```

The Flox environment provides Terraform, curl, jq, and SSH. If Flox says a package lock is missing or asks you to log in, run `flox auth login` and `flox install terraform@1.16.5 curl jq openssh` from the repository root, then activate it again. Commit the generated `.flox/env/manifest.lock` when available; never edit it manually. Docker on your laptop is **not** needed to deploy this VPS.

## 2. Prepare Hetzner and your SSH key

1. Sign in at [Hetzner Console](https://console.hetzner.com/) and create or open a **Cloud project**. Terraform will put the VPS and firewall in whichever project your API token belongs to. Do not manually create a server.
2. On the computer that will run Terraform, create an SSH key pair if you do not already have one you want to use:

   ```bash
   mkdir -p "$HOME/.ssh"
   chmod 700 "$HOME/.ssh"
   ssh-keygen -t ed25519 -f "$HOME/.ssh/ordreflow-test" -C "ordreflow-test"
   cat "$HOME/.ssh/ordreflow-test.pub"
   ```

   `ssh-keygen` may ask for a passphrase. Copy the **public** key printed by the last command (the `.pub` file); keep the private file `~/.ssh/ordreflow-test` on your own computer. If you already have a key pair, use its `.pub` file instead of overwriting it.
3. In your Hetzner project, open **Security → SSH Keys**, add the public key, and give the entry a name, for example `ordreflow-test`. Set `ssh_key_name` in `terraform.tfvars` to **that Hetzner entry's name**, not the key contents or the path on your computer. The key has to exist in this project *before* `terraform apply`.
4. In the same project, open **Security → API Tokens → Generate API Token**. Name it something like `ordreflow-test-terraform`, select **Read & Write**, and copy the token when shown. This is the value for the shell variable `HCLOUD_TOKEN`, **not** a `tfvars` entry. Hetzner only displays it once. [Hetzner's token instructions](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)

### Find your SSH firewall IP

On the computer/network from which you will SSH into the VPS, run:

```bash
curl -4 https://api.ipify.org
```

If it prints `198.51.100.24`, set `ssh_allowed_cidrs = ["198.51.100.24/32"]` (replace this example with **your** result). `/32` means only that one public IPv4 address can SSH in. This is **your laptop/network's** public IP, not the VPS IP; if your network's IP later changes, update the value and reapply Terraform. The sample `203.0.113.10/32` in the example file is a documentation address and will not let you in.

## 3. Prepare Cloudflare DNS

1. Have an active domain in [Cloudflare](https://dash.cloudflare.com/), such as `example.com`. Pick an unused hostname under it, such as `test.example.com`. Put that **full hostname** in `hostname`; Terraform creates the A record automatically. Do not create that record yourself (if it already exists, choose another unused name).
2. Select the domain in Cloudflare, open **Overview**, and copy **Zone ID** from the **API** section near the bottom. Put this ID in `cloudflare_zone_id`—it is *not* your Account ID. [Cloudflare's Zone ID instructions](https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/)
3. Open **My Profile → API Tokens → Create Token**. Choose the **Edit zone DNS** template, scope it to this one domain/zone, create it, and copy the token. Export it as `CLOUDFLARE_API_TOKEN` in your shell, not in `terraform.tfvars`. [Cloudflare's token instructions](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)

Terraform creates a **DNS-only** record (Cloudflare proxy off). The Caddy container on the VPS obtains the HTTPS certificate once the record resolves.

## 4. Find your three container images

You need the **full public image reference**, including an actual version tag or digest, for each service:

| `terraform.tfvars` key | What to look for |
| --- | --- |
| `api_image` | Runtime API image published from `ordreflow-backend` |
| `migrations_image` | Image published from `ordreflow-backend` using the Dockerfile's `migration` target |
| `frontend_image` | Frontend image published from `ordreflow-frontend` |

If they are in GitHub Container Registry, open the organization's [Packages page](https://github.com/orgs/ordreflow/packages), select each package and version, and copy its `ghcr.io/...:<tag>` reference from the install/pull instructions. The strings in `terraform.tfvars.example` are **illustrations**, not confirmed package names or published tags. Use API and migration images from the *same backend revision*. If a package or migration-target image is missing, publish it before deploying; Terraform pulls images but does not build them.

## 5. Fill in `terraform.tfvars`

From the repository root:

```bash
cp terraform/environments/test/terraform.tfvars.example terraform/environments/test/terraform.tfvars
```

Open `terraform/environments/test/terraform.tfvars` in your editor and replace **every** example hostname, ID, key name, IP, and image tag using steps 2–4. Values are strings in quotes; `ssh_allowed_cidrs` is a list in brackets. The defaults for `server_name` (`ordreflow-test`), `server_type` (`cx23`), and `location` (`fsn1`, Falkenstein) can be left alone. If a server named `ordreflow-test` already exists in the Hetzner project, set a different `server_name` in the file. Check the server type's current price in Hetzner Console before applying.

Export the two API tokens in the **same terminal** where you will run Terraform. Replace the text between quotes with the tokens you just copied:

```bash
export HCLOUD_TOKEN='paste-Hetzner-Read-Write-token-here'
export CLOUDFLARE_API_TOKEN='paste-Cloudflare-Edit-zone-DNS-token-here'
```

Neither API token, your SSH private key, nor a database password belongs in `terraform.tfvars`. The example file is safe to share; your filled-in file is ignored by Git. Database and JWT secrets are generated on the VPS at first boot.

## 6. Create the environment

Still at the repository root with Flox active and the tokens exported:

```bash
terraform -chdir=terraform/environments/test init
terraform -chdir=terraform/environments/test validate
terraform -chdir=terraform/environments/test plan
terraform -chdir=terraform/environments/test apply
terraform -chdir=terraform/environments/test output -raw url
terraform -chdir=terraform/environments/test output -raw server_ipv4
```

`plan` only previews changes; `apply` asks you to confirm before creating the billed VPS. The first `apply` should propose one VPS, one firewall, and one DNS record. `apply` finishes before cloud-init has necessarily finished installing Docker or Caddy has obtained its certificate, so allow a few minutes before checking the website.

## 7. Check it and log in

From the repository root, copy these commands. They read the server IP and URL from Terraform's outputs. Use the private key from step 2 (change its path if you registered a different one):

```bash
SERVER_IP="$(terraform -chdir=terraform/environments/test output -raw server_ipv4)"
TEST_URL="$(terraform -chdir=terraform/environments/test output -raw url)"
ssh -i "$HOME/.ssh/ordreflow-test" "root@$SERVER_IP" 'cloud-init status --wait'
ssh -i "$HOME/.ssh/ordreflow-test" "root@$SERVER_IP" 'systemctl status ordreflow-compose.service --no-pager'
ssh -i "$HOME/.ssh/ordreflow-test" "root@$SERVER_IP" 'docker compose -f /opt/ordreflow/compose.yaml ps -a'
curl -fsS "$TEST_URL/api/health"
```

`migrations` and `seed` should show successful exits; PostgreSQL, API, frontend, and Caddy should be running. The health endpoint returns `{"status":"ok"}`. Open the URL printed by `terraform output url` and use a demo login from [`docker/local/README.md`](../../../docker/local/README.md), for example `casey.employee@example.com` / `DemoEmployee123!`. The seed SQL creates these login accounts after migrations and can rerun without duplicating the rows.

If first boot fails, SSH into the server and check `cloud-init status --long`, `journalctl -u ordreflow-compose.service --no-pager`, or `docker compose -f /opt/ordreflow/compose.yaml logs migrations seed`.

## 8. Destroy it when finished

From the **same checkout** that created the environment:

```bash
terraform -chdir=terraform/environments/test destroy
```

This deletes the DNS record, firewall, VPS, and its database data. The database survives reboots, but not server replacement or destruction. Keep the ignored `terraform.tfstate` file until after destruction: it tells Terraform which resources belong to this deployment. If someone else needs to take over deployment, transfer the state securely or configure a shared Terraform backend before they run `apply`/`destroy`.
