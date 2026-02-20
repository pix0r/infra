# Generate an ED25519 key pair for server access
resource "tls_private_key" "server" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "default" {
  name       = "infra-bootstrap"
  public_key = tls_private_key.server.public_key_openssh
}

# Write private key to local file for SSH access
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.server.private_key_openssh
  filename        = "${path.module}/.ssh/id_ed25519"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.server.public_key_openssh
  filename        = "${path.module}/.ssh/id_ed25519.pub"
  file_permission = "0644"
}
