output "server_ipv4" {
  description = "Primary server public IPv4"
  value       = hcloud_server.primary.ipv4_address
}

output "server_ipv6" {
  description = "Primary server public IPv6"
  value       = hcloud_server.primary.ipv6_address
}

output "coolify_url" {
  description = "Coolify dashboard URL"
  value       = "https://${local.coolify_fqdn}"
}

output "forgejo_url" {
  description = "Forgejo URL"
  value       = "https://${local.forgejo_fqdn}"
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh -i ${path.module}/.ssh/id_ed25519 root@${hcloud_server.primary.ipv4_address}"
}

output "ssh_private_key" {
  description = "Path to generated SSH private key"
  value       = local_file.ssh_private_key.filename
  sensitive   = true
}
