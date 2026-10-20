locals {
  deployment_env = join("\n", [
    "API_IMAGE=${var.api_image}",
    "FRONTEND_IMAGE=${var.frontend_image}",
    "MIGRATIONS_IMAGE=${var.migrations_image}",
    "TEST_DOMAIN=${var.hostname}",
  ])

  # Keep Docker Compose and Caddy as ordinary files. Only the non-secret image
  # references and hostname enter user_data; credentials are generated on boot.
  cloud_init = "#cloud-config\n${yamlencode({
    package_update = true
    packages       = ["docker.io", "docker-compose-v2", "openssl"]
    write_files = [
      {
        path        = "/opt/ordreflow/compose.yaml"
        encoding    = "b64"
        permissions = "0644"
        content     = filebase64("${path.module}/files/compose.yaml")
      },
      {
        path        = "/opt/ordreflow/Caddyfile"
        encoding    = "b64"
        permissions = "0644"
        content     = filebase64("${path.module}/files/Caddyfile")
      },
      {
        path        = "/opt/ordreflow/seed-demo.sql"
        encoding    = "b64"
        permissions = "0644"
        content     = base64encode(var.demo_seed_sql)
      },
      {
        path        = "/opt/ordreflow/deployment.env"
        encoding    = "b64"
        permissions = "0644"
        content     = base64encode("${local.deployment_env}\n")
      },
      {
        path        = "/etc/systemd/system/ordreflow-compose.service"
        encoding    = "b64"
        permissions = "0644"
        content     = filebase64("${path.module}/files/ordreflow-compose.service")
      },
    ]
    runcmd = [
      ["install", "-d", "-m", "0700", "/opt/ordreflow"],
      ["bash", "-ceu", <<-EOT
        if [ ! -f /opt/ordreflow/.env ]; then
          umask 077
          tmp=$(mktemp /opt/ordreflow/.env.XXXXXX)
          cp /opt/ordreflow/deployment.env "$tmp"
          printf 'DB_NAME=ordreflow\nDB_USERNAME=ordreflow\nDB_PASSWORD=%s\nJWT_SECRET=%s\n' \
            "$(openssl rand -hex 32)" "$(openssl rand -hex 48)" >> "$tmp"
          mv "$tmp" /opt/ordreflow/.env
        fi
      EOT
      ],
      ["systemctl", "enable", "--now", "docker"],
      ["systemctl", "daemon-reload"],
      ["systemctl", "enable", "--now", "ordreflow-compose.service"],
    ]
  })}"
}

resource "hcloud_firewall" "test" {
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

  labels = {
    application = "ordreflow"
    environment = "test"
  }
}

resource "hcloud_server" "test" {
  name         = var.server_name
  image        = "ubuntu-24.04"
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [var.ssh_key_name]
  firewall_ids = [hcloud_firewall.test.id]
  user_data    = local.cloud_init

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = {
    application = "ordreflow"
    environment = "test"
  }

  lifecycle {
    precondition {
      condition     = length(local.cloud_init) <= 32768
      error_message = "Hetzner Cloud user_data must be 32 KiB or smaller."
    }
  }
}
