variable "hostname" {
  description = "Unused test subdomain within the Cloudflare zone, e.g. test.example.com."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID containing the test hostname."
  type        = string
}

variable "ssh_key_name" {
  description = "Existing Hetzner Cloud SSH public key name."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Your IPv4 address(es) with /32 suffix, or other restricted IPv4 CIDRs."
  type        = list(string)
}

variable "api_image" {
  description = "Public, versioned API image."
  type        = string
}

variable "frontend_image" {
  description = "Public, versioned frontend image."
  type        = string
}

variable "migrations_image" {
  description = "Public, versioned image built from the backend migration target."
  type        = string
}

variable "server_name" {
  description = "Name for the test server and firewall."
  type        = string
  default     = "ordreflow-test"
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner Cloud server location."
  type        = string
  default     = "fsn1"
}
