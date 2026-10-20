output "ipv4_address" {
  description = "Public IPv4 address for DNS and SSH."
  value       = hcloud_server.test.ipv4_address
}

output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = hcloud_server.test.id
}
