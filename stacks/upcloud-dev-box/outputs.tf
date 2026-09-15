output "server_ipv4" {
  description = "Dev box public IPv4 (null when var.enabled = false)"
  value       = one(upcloud_server.dev_box[*].network_interface[0].ip_address)
}

output "ssh_command" {
  description = "SSH in as the non-root dev user"
  value       = var.enabled ? "ssh dev@${one(upcloud_server.dev_box[*].network_interface[0].ip_address)}" : null
}

output "mosh_command" {
  description = "Same, over mosh"
  value       = var.enabled ? "mosh dev@${one(upcloud_server.dev_box[*].network_interface[0].ip_address)}" : null
}

output "orchestrator_tunnel_command" {
  description = "Forward the orchestrator UI to http://localhost:4000 on your laptop"
  value       = var.enabled ? "ssh -N -L 4000:localhost:4000 dev@${one(upcloud_server.dev_box[*].network_interface[0].ip_address)}" : null
}

output "data_storage_id" {
  description = "UUID of the persistent /data storage"
  value       = upcloud_storage.data.id
}

output "fqdn" {
  description = "Public DNS name of the box (null when disabled)"
  value       = one(aws_route53_record.dev_box[*].fqdn)
}
