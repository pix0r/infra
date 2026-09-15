# --- Hetzner ---
variable "hcloud_token" {
  description = "Hetzner Cloud API token (TF_VAR_hcloud_token from secrets/terraform.env)"
  type        = string
  sensitive   = true
}

variable "enabled" {
  description = "Create the server (true) or destroy it (false). The data volume, firewall and SSH keys persist either way. Flip and merge to turn the box on/off."
  type        = bool
  default     = false
}

variable "server_name" {
  description = "Hetzner server name. Must equal the NixOS networking.hostName (comin deploys nixosConfigurations.<hostName>)."
  type        = string
  default     = "dev-box"
}

variable "server_type" {
  description = "Hetzner server type. cpx22 = 2 vCPU / 4 GB / 80 GB x86 in the US, ~USD 23/mo (2026-09); cpx32 (4/8) ~USD 42. EU-only cx33 (4/8) is ~EUR 8.49 but ~150 ms from California."
  type        = string
  default     = "cpx22"
}

variable "server_location" {
  description = "Hetzner location. ash (Ashburn) / hil (Hillsboro) for US; cx*/cax* types exist only in fsn1 / nbg1 / hel1. The API rejects unavailable type+location pairs at plan time."
  type        = string
  default     = "ash"
}

variable "server_image" {
  description = "Base image that nixos-infect converts to NixOS on first boot. Keep an Ubuntu LTS."
  type        = string
  default     = "ubuntu-24.04"
}

variable "volume_size" {
  description = "Size in GB of the persistent /data volume (home dirs, repos, docker). Grows in place; never shrinks."
  type        = number
  default     = 20
}

# --- Bootstrap ---
variable "github_user" {
  description = "GitHub user whose public SSH keys are registered at Hetzner (root, first boot) and baked into the NixOS config (dev user)"
  type        = string
  default     = "pix0r"
}

variable "nixos_channel" {
  description = "Channel nixos-infect installs before handing over to the flake. Keep in step with the nixpkgs input in flake.nix."
  type        = string
  default     = "nixos-26.05"
}

variable "nixos_infect_ref" {
  description = "Pinned commit of github.com/elitak/nixos-infect to run. Bump deliberately."
  type        = string
  default     = "40f62a680bb0e8f2f607d79abfaaecd99d59401c"
}

variable "flake_ref" {
  description = "Flake reference the box switches to after infect. Must be reachable without credentials (public repo)."
  type        = string
  default     = "github:pix0r/infra#dev-box"
}
