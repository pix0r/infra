# Private search workload. Dataset and index survive replacement on /data.
# Provision the brain checkout as dev before enabling access; see stack README.
{ pkgs, ... }:
let
  root = "/data/lifedata";
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  launch = pkgs.writeShellScript "personal-search" ''
    set -euo pipefail
    dns_name="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r '.Self.DNSName // empty | rtrimstr(".")' || true)"
    proxy_args=()
    if [ -n "$dns_name" ]; then
      proxy_args+=(--allowed-host "$dns_name:8443")
    fi
    exec ${python}/bin/python ${root}/brain/scripts/personal_search_web.py \
      --brain ${root}/brain --index ${root}/index/search.sqlite "''${proxy_args[@]}"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${root} 0750 dev users -"
    "d ${root}/archive 0700 dev users -"
    "d ${root}/index 0700 dev users -"
  ];

  systemd.services.personal-search = {
    description = "Private LifeData browser and read-only search API";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    unitConfig = {
      RequiresMountsFor = root;
      ConditionPathExists = "${root}/brain/scripts/personal_search_web.py";
    };
    environment.PYTHONDONTWRITEBYTECODE = "1";
    serviceConfig = {
      User = "dev";
      Group = "users";
      WorkingDirectory = "${root}/brain";
      ExecStartPre = "${python}/bin/python ${root}/brain/scripts/personal_search.py --brain ${root}/brain --index ${root}/index/search.sqlite index";
      ExecStart = launch;
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "${root}/index" ];
      InaccessiblePaths = [ "${root}/archive" ];
    };
  };
  # Listener stays on 127.0.0.1. No public firewall ports and no agent dispatch.
}
