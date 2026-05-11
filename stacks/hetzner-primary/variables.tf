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
  description = "AWS credentials profile name from ~/.aws/credentials. Leave empty to use env vars (AWS_ACCESS_KEY_ID/SECRET) — the provider falls back to standard SDK credential resolution."
  type        = string
  default     = ""
}

# --- App domains ---
variable "apps_wildcard" {
  description = "Wildcard domain for deployed apps (also covers app.matz.io for orchestrator admin UI)"
  type        = string
  default     = "*.app.matz.io"
}

variable "share_fqdn" {
  description = "FQDN for the publish-slice (separate auth posture from apps.*). TENTATIVE — may unify with share.pixor.net in Sprint 4."
  type        = string
  default     = "share.matz.io"
}

# --- Flux GitOps ---
variable "flux_github_pat" {
  description = "GitHub PAT for Flux bootstrap. Needs `repo` scope on pix0r/infra (read+write so Flux can commit its bootstrap manifests). Optionally read on pix0r/brain-orchestrator for the chart."
  type        = string
  sensitive   = true
}

locals {
  apps_fqdn  = var.apps_wildcard
  share_fqdn = var.share_fqdn
}
