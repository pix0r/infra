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

variable "aws_profile" {
  description = "AWS credentials profile name from ~/.aws/credentials"
  type        = string
}

# --- Coolify ---
variable "coolify_fqdn" {
  description = "FQDN for Coolify dashboard"
  type        = string
  default     = "deploy.matz.io"
}

variable "forgejo_fqdn" {
  description = "FQDN for Forgejo"
  type        = string
  default     = "dev.matz.io"
}

variable "apps_wildcard" {
  description = "Wildcard domain for deployed apps"
  type        = string
  default     = "*.app.matz.io"
}

locals {
  coolify_fqdn = var.coolify_fqdn
  forgejo_fqdn = var.forgejo_fqdn
  apps_fqdn    = var.apps_wildcard
}
