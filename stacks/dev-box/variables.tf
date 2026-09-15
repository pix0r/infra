# --- Hetzner ---
variable "hcloud_token" {
  description = "Hetzner Cloud API token (TF_VAR_hcloud_token from secrets/terraform.env)"
  type        = string
  sensitive   = true
}

variable "enabled" {
  description = "Create the box (true) or destroy it while keeping firewall + SSH keys (false). Flip and merge to turn the box on/off."
  type        = bool
  default     = true
}

variable "server_name" {
  description = "Hetzner server name"
  type        = string
  default     = "dev-box"
}

variable "server_type" {
  description = "Hetzner server type. cpx31 = 4 vCPU / 8 GB x86, ~EUR 15/mo hourly-billed. Cheaper: cpx21 (3 vCPU / 4 GB). ARM (cax*) may not be offered in ash; the API rejects unavailable type/location pairs."
  type        = string
  default     = "cpx31"
}

variable "server_location" {
  description = "Hetzner location (ash = Ashburn, US-east)"
  type        = string
  default     = "ash"
}

variable "server_image" {
  description = "OS image. cloud-init assumes Ubuntu."
  type        = string
  default     = "ubuntu-24.04"
}

# --- Box contents ---
variable "github_user" {
  description = "GitHub user whose public SSH keys are authorized on the box (root via Hetzner, dev via cloud-init ssh_import_id)"
  type        = string
  default     = "pix0r"
}

variable "claude_code_version" {
  description = "npm version spec for @anthropic-ai/claude-code baked into the image. Pin (e.g. 2.1.0) for reproducible boxes."
  type        = string
  default     = "latest"
}
