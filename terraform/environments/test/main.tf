module "ordreflow_test_vps" {
  source = "../../modules/ordreflow-test-vps"

  server_name       = var.server_name
  server_type       = var.server_type
  location          = var.location
  ssh_key_name      = var.ssh_key_name
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  hostname          = var.hostname
  api_image         = var.api_image
  frontend_image    = var.frontend_image
  migrations_image  = var.migrations_image
  demo_seed_sql     = file("${path.root}/../../../docker/local/seed-demo.sql")
}

# DNS-only lets Caddy request and renew the origin's HTTPS certificate directly.
resource "cloudflare_dns_record" "test" {
  zone_id = var.cloudflare_zone_id
  name    = var.hostname
  type    = "A"
  content = module.ordreflow_test_vps.ipv4_address
  ttl     = 1
  proxied = false
}
