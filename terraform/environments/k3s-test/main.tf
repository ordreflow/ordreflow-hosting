locals {
  # Cloud-init only installs K3s. The apply-time bootstrap registers a public
  # deploy key and creates secrets on the host without storing them in state.
  cloud_init = "#cloud-config\n${yamlencode({
    package_update = true
    packages       = ["curl", "ca-certificates"]
    runcmd = [
      ["bash", "-ceu", <<-EOT
        curl -sfL https://get.k3s.io -o /root/install-k3s.sh
        INSTALL_K3S_VERSION='${var.k3s_version}' sh /root/install-k3s.sh server --write-kubeconfig-mode 0600
      EOT
      ],
    ]
  })}"
}

resource "hcloud_firewall" "k3s" {
  name = "${var.server_name}-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0"]
  }

  labels = { application = "ordreflow", environment = "k3s-test" }
}

resource "hcloud_server" "k3s" {
  name         = var.server_name
  image        = "ubuntu-24.04"
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [var.ssh_key_name]
  firewall_ids = [hcloud_firewall.k3s.id]
  user_data    = local.cloud_init

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = { application = "ordreflow", environment = "k3s-test" }

  lifecycle {
    precondition {
      condition     = length(local.cloud_init) <= 32768
      error_message = "Hetzner Cloud user_data must be 32 KiB or smaller."
    }
  }
}

# DNS-only allows Let's Encrypt HTTP-01 validation through K3s Traefik.
resource "cloudflare_dns_record" "k3s" {
  zone_id = var.cloudflare_zone_id
  name    = var.hostname
  type    = "A"
  content = hcloud_server.k3s.ipv4_address
  ttl     = 1
  proxied = false
}

# Create a deploy key on the server, not in Terraform state. The public key is
# safe to store in state; GitHub credentials are read by the provider from GITHUB_TOKEN.
resource "terraform_data" "flux_key" {
  triggers_replace = [hcloud_server.k3s.id]

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/create-flux-key.sh"
    environment = {
      SERVER_IP            = hcloud_server.k3s.ipv4_address
      SSH_PRIVATE_KEY_PATH = pathexpand(var.ssh_private_key_path)
    }
  }
}

data "external" "flux_public_key" {
  depends_on = [terraform_data.flux_key]
  program    = ["bash", "${path.module}/scripts/read-flux-key.sh"]
  query = {
    server_ip            = hcloud_server.k3s.ipv4_address
    ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  }
}

resource "github_repository_deploy_key" "flux" {
  repository = "ordreflow-hosting"
  title      = "${var.server_name}-flux"
  key        = data.external.flux_public_key.result.public_key
  read_only  = false
}

# Secrets are sent via an ephemeral provisioner environment to the server over
# SSH. Terraform state and Hetzner user_data contain no GitHub or app secrets.
resource "terraform_data" "bootstrap" {
  triggers_replace = [
    hcloud_server.k3s.id,
    github_repository_deploy_key.flux.id,
    filesha256("${path.module}/scripts/bootstrap-remote.sh"),
    filesha256("${path.module}/scripts/run-bootstrap.sh"),
    var.hostname,
    var.acme_email,
    var.ghcr_username,
  ]
  depends_on = [cloudflare_dns_record.k3s]

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/run-bootstrap.sh"
    environment = {
      SERVER_IP            = hcloud_server.k3s.ipv4_address
      SSH_PRIVATE_KEY_PATH = pathexpand(var.ssh_private_key_path)
      BOOTSTRAP_SCRIPT     = "${path.module}/scripts/bootstrap-remote.sh"
      GHCR_USERNAME        = var.ghcr_username
      GHCR_TOKEN           = var.ghcr_token
      APP_HOST             = var.hostname
      ACME_EMAIL           = var.acme_email
    }
  }
}
