output "url" {
  description = "HTTPS URL for the test frontend."
  value       = "https://${var.hostname}"
}

output "server_ipv4" {
  description = "Public IPv4 address for SSH and troubleshooting."
  value       = module.ordreflow_test_vps.ipv4_address
}

output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = module.ordreflow_test_vps.server_id
}
