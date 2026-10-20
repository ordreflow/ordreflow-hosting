variable "server_name" {
  description = "Unique Hetzner Cloud server name."
  type        = string
  default     = "ordreflow-test"
}

variable "server_type" {
  description = "Hetzner Cloud x86 server type (CX23 provides room for the .NET migration image)."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
  default     = "fsn1"
}

variable "ssh_key_name" {
  description = "Name of an SSH public key already registered in the Hetzner Cloud project."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 CIDR ranges allowed to access SSH."
  type        = list(string)

  validation {
    condition = length(var.ssh_allowed_cidrs) > 0 && alltrue([
      for cidr in var.ssh_allowed_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/(3[0-2]|[12]?[0-9])$", cidr)) && can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Supply at least one restricted IPv4 SSH CIDR (not 0.0.0.0/0)."
  }
}

variable "hostname" {
  description = "Full DNS name where Caddy will obtain a TLS certificate."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.hostname))
    error_message = "hostname must be a lowercase fully qualified domain name."
  }
}

variable "api_image" {
  description = "Public, versioned API container image reference."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._:/@-]+$", var.api_image))
    error_message = "api_image must be a single container image reference without whitespace."
  }
}

variable "frontend_image" {
  description = "Public, versioned frontend container image reference."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._:/@-]+$", var.frontend_image))
    error_message = "frontend_image must be a single container image reference without whitespace."
  }
}

variable "migrations_image" {
  description = "Public migration image built from the backend Dockerfile's migration target."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._:/@-]+$", var.migrations_image))
    error_message = "migrations_image must be a single container image reference without whitespace."
  }
}

variable "demo_seed_sql" {
  description = "SQL demo records to load after migrations on a new test server."
  type        = string
}
