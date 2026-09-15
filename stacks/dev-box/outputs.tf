output "server_ipv4" {
  description = "Dev box public IPv4 (null when var.enabled = false)"
  value       = one(hcloud_server.dev_box[*].ipv4_address)
}

output "ssh_command" {
  description = "SSH in as the non-root dev user (Claude Code refuses --dangerously-skip-permissions as root)"
  value       = var.enabled ? "ssh dev@${one(hcloud_server.dev_box[*].ipv4_address)}" : null
}

output "mosh_command" {
  description = "Same, over mosh (roams, survives sleep)"
  value       = var.enabled ? "mosh dev@${one(hcloud_server.dev_box[*].ipv4_address)}" : null
}

output "orchestrator_tunnel_command" {
  description = "Forward the orchestrator UI to http://localhost:4000 on your laptop"
  value       = var.enabled ? "ssh -N -L 4000:localhost:4000 dev@${one(hcloud_server.dev_box[*].ipv4_address)}" : null
}

output "data_volume_id" {
  description = "Hetzner id of the persistent /data volume (device /dev/disk/by-id/scsi-0HC_Volume_<id>)"
  value       = hcloud_volume.data.id
}
