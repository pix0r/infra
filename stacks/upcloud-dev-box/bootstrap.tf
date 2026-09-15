# Install NixOS over SSH with nixos-anywhere, once per server instance.
# Re-runs only when the server is (re)created. Needs `nix` and `ssh` on the
# machine running `tofu apply` — deploy.yml installs nix; a laptop without nix
# cannot apply this stack (plan is fine).
resource "terraform_data" "nixos_anywhere" {
  count = var.enabled ? 1 : 0

  triggers_replace = [upcloud_server.dev_box[0].id]

  input = {
    ip = upcloud_server.dev_box[0].network_interface[0].ip_address
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      IP='${self.input.ip}'
      KEY='${local_sensitive_file.bootstrap_key.filename}'
      SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes"
      echo "waiting for cloud-init on $IP"
      for i in $(seq 1 60); do
        $SSH root@$IP 'test -f /var/lib/cloud/instance/boot-finished' 2>/dev/null && break
        sleep 10
      done
      $SSH root@$IP 'cat /var/log/label-data-volume.log'
      REPO=$(git rev-parse --show-toplevel)
      nix run "github:nix-community/nixos-anywhere/${var.nixos_anywhere_ref}" -- \
        --flake "$REPO#${var.flake_attr}" \
        -i "$KEY" \
        --ssh-option StrictHostKeyChecking=no \
        --ssh-option UserKnownHostsFile=/dev/null \
        root@$IP
    EOT
  }
}
