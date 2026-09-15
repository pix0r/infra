variable "enabled" {
  description = "Create the server (true) or destroy it (false). The /data storage persists either way. Flip and merge to turn the box on/off."
  type        = bool
  default     = true
}

variable "hostname" {
  description = "Server hostname. Must equal networking.hostName in hosts/<name>/configuration.nix (comin deploys nixosConfigurations.<hostName>)."
  type        = string
  default     = "dev-box"
}

variable "zone" {
  description = "UpCloud zone. us-sjo1 = San Jose (~15 ms from San Diego). `upctl zone list` or GET /1.3/zone."
  type        = string
  default     = "us-sjo1"
}

variable "plan" {
  description = "UpCloud plan name, e.g. 4xCPU-8GB. Confirm against GET /1.3/plan (names and prices change; the API rejects unknown plans at plan time)."
  type        = string
  default     = "4xCPU-8GB"
}

variable "template" {
  description = "OS template that boots first. nixos-anywhere wipes it and installs NixOS over SSH. Any cloud-init Linux works; Ubuntu LTS is the tested one."
  type        = string
  default     = "Ubuntu Server 24.04 LTS (Noble Numbat)"
}

variable "root_size" {
  description = "Root disk GB. Wiped on every (re)install; nothing worth keeping lives here."
  type        = number
  default     = 50
}

variable "data_size" {
  description = "Persistent /data storage GB (home dirs, repos, docker). Grows in place; never shrinks."
  type        = number
  default     = 20
}

variable "data_tier" {
  description = "Storage tier for /data: maxiops (fast, ~USD 0.25/GB) or standard (~USD 0.10/GB)."
  type        = string
  default     = "maxiops"
}

variable "github_user" {
  description = "GitHub user whose public SSH keys are authorized on the box (root during bootstrap; also baked into the NixOS config)."
  type        = string
  default     = "pix0r"
}

variable "flake_attr" {
  description = "nixosConfigurations.<attr> in the repo-root flake that nixos-anywhere installs."
  type        = string
  default     = "dev-box"
}

variable "nixos_anywhere_ref" {
  description = "Pinned nixos-anywhere release used by the install step."
  type        = string
  default     = "1.13.0"
}
