output "server_ipv4" {
  description = "Primary server public IPv4"
  value       = hcloud_server.primary.ipv4_address
}

output "server_ipv6" {
  description = "Primary server public IPv6"
  value       = hcloud_server.primary.ipv6_address
}

output "orchestrator_url" {
  description = "Orchestrator admin URL"
  value       = "https://app.matz.io"
}

output "share_url" {
  description = "Publish-slice URL"
  value       = "https://${local.share_fqdn}"
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

output "kubeconfig_command" {
  description = "Copy kubeconfig from server (and rewrite the localhost API endpoint to the public IP)"
  value       = "scp -i ${path.module}/.ssh/id_ed25519 root@${hcloud_server.primary.ipv4_address}:/etc/rancher/k3s/k3s.yaml ./k3s.yaml && sed -i '' 's/127.0.0.1/${hcloud_server.primary.ipv4_address}/' ./k3s.yaml"
}

output "flux_status_command" {
  description = "Check Flux reconciliation status"
  value       = "ssh -i ${path.module}/.ssh/id_ed25519 root@${hcloud_server.primary.ipv4_address} 'flux get all -A'"
}
