# --- Hetzner ---
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cax31" # ARM, 8GB RAM, 4 vCPU, 80GB disk
}

variable "server_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "ash" # Ashburn, VA (US East)
}

variable "server_image" {
  description = "OS image for the server"
  type        = string
  default     = "ubuntu-24.04"
}

# --- DNS ---
variable "domain" {
  description = "Base domain (must exist as a Route 53 hosted zone)"
  type        = string
}

variable "subdomain_prefix" {
  description = "Prefix for service subdomains (e.g., 'lab' gives git.lab.example.com)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for the domain"
  type        = string
}

# --- AWS (for Route 53 only) ---
variable "aws_region" {
  description = "AWS region (only used for Route 53 API calls)"
  type        = string
  default     = "us-east-1"
}

# --- Coolify ---
variable "coolify_fqdn" {
  description = "FQDN for Coolify dashboard (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "forgejo_fqdn" {
  description = "FQDN for Forgejo (auto-generated if empty)"
  type        = string
  default     = ""
}

# --- SSH ---
variable "ssh_public_key_path" {
  description = "Path to SSH public key for server access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

locals {
  base_domain  = var.subdomain_prefix != "" ? "${var.subdomain_prefix}.${var.domain}" : var.domain
  coolify_fqdn = var.coolify_fqdn != "" ? var.coolify_fqdn : "coolify.${local.base_domain}"
  forgejo_fqdn = var.forgejo_fqdn != "" ? var.forgejo_fqdn : "git.${local.base_domain}"
  apps_fqdn    = "*.apps.${local.base_domain}"
}
