variable "hostname" {
  description = "Unused test subdomain, e.g. k3s-test.example.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.hostname))
    error_message = "hostname must be a lowercase fully qualified domain name."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone containing hostname."
  type        = string
}

variable "ssh_key_name" {
  description = "Existing Hetzner Cloud SSH key name."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Restricted IPv4 CIDR ranges allowed to reach SSH."
  type        = list(string)

  validation {
    condition = length(var.ssh_allowed_cidrs) > 0 && alltrue([
      for cidr in var.ssh_allowed_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(3[0-2]|[12]?[0-9])$", cidr)) && can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Supply at least one restricted SSH CIDR (not 0.0.0.0/0)."
  }
}

variable "server_name" {
  type    = string
  default = "ordreflow-k3s-test"
}

variable "server_type" {
  description = "CX33 has room for K3s, Flux, PostgreSQL and the .NET migration image."
  type        = string
  default     = "cx33"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "k3s_version" {
  description = "Pinned upstream K3s version."
  type        = string
  default     = "v1.37.2+k3s1"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "k3s_version must be a pinned version such as v1.37.2+k3s1."
  }
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key registered under ssh_key_name. Only its path enters Terraform state."
  type        = string
  default     = "~/.ssh/ordreflow-test"
}

variable "acme_email" {
  description = "Let's Encrypt contact address; also used for the first application admin login."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.acme_email))
    error_message = "acme_email must be a valid email address."
  }
}
