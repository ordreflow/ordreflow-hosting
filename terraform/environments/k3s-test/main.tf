locals {
  # Cluster credentials and application secrets are deliberately not stored in
  # Terraform state or cloud-init. Flux and secrets are bootstrapped separately.
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
