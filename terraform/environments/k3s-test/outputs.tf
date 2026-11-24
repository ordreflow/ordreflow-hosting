output "url" {
  value = "https://${var.hostname}"
}

output "server_ipv4" {
  value = hcloud_server.k3s.ipv4_address
}

output "server_id" {
  value = hcloud_server.k3s.id
}
