# Private source is fetched at runtime, never copied into the world-readable store.
{ pkgs, ... }:
let
  root = "/data/lifedata";
  # Update this pin through a PR to deploy code AND the curated source snapshot.
  revision = "ab210e68aa6bb9b468c5d9545a9e73592c8a85bb";
  release = "${root}/releases/${revision}";
  index = "${root}/index/${revision}.sqlite";
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  provision = pkgs.writeShellScript "personal-search-provision"
    (builtins.readFile ./personal-search-provision.sh);
  launch = pkgs.writeShellScript "personal-search" ''
    set -euo pipefail
    dns_name="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -er '.Self.DNSName | select(length > 0) | rtrimstr(".")')"
    exec ${python}/bin/python ${release}/scripts/personal_search_web.py \
      --brain ${release} --index ${index} --allowed-host "$dns_name:8443"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${root} 0750 dev users -"
    "d ${root}/archive 0700 dev users -"
    "d ${root}/releases 0700 dev users -"
    "d ${root}/index 0700 dev users -"
  ];

  systemd.services.personal-search-prepare = {
    description = "Provision pinned private LifeData source and index";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "personal-search.service" ];
    partOf = [ "personal-search.service" ];
    unitConfig.RequiresMountsFor = root;
    path = [ pkgs.git pkgs.coreutils ];
    environment = {
      HOME = "/data/home/dev";
      GH_CONFIG_DIR = "/data/home/dev/.config/gh";
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "credential.helper";
      GIT_CONFIG_VALUE_0 = "!${pkgs.gh}/bin/gh auth git-credential";
      PYTHONDONTWRITEBYTECODE = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "dev";
      Group = "users";
      ExecStart = "${provision} ${root} https://github.com/pix0r/brain.git ${revision} ${python}/bin/python";
      TimeoutStartSec = "5min";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "${root}/releases" "${root}/index" ];
      InaccessiblePaths = [ "${root}/archive" ];
    };
  };

  systemd.services.personal-search = {
    description = "Private LifeData browser and read-only search API";
    wantedBy = [ "multi-user.target" ];
    wants = [ "personal-search-https.service" ];
    requires = [ "personal-search-prepare.service" "tailscaled.service" ];
    after = [ "personal-search-prepare.service" "tailscaled.service" ];
    unitConfig.RequiresMountsFor = root;
    environment = {
      PYTHONDONTWRITEBYTECODE = "1";
      SEARCH_INDEX = index; # Shared with the side-by-side LiveView comparison.
    };
    serviceConfig = {
      User = "dev";
      Group = "users";
      WorkingDirectory = release;
      ExecStart = launch;
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      InaccessiblePaths = [ "${root}/archive" "/data/home/dev" ];
    };
  };

  # Own only HTTPS 8443. Other Serve endpoints are left alone; never enable Funnel.
  systemd.services.personal-search-https = {
    description = "Private Tailscale HTTPS for LifeData search";
    wantedBy = [ "multi-user.target" ];
    requires = [ "tailscaled.service" "personal-search.service" ];
    after = [ "tailscaled.service" "personal-search.service" ];
    partOf = [ "personal-search.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --bg --https=8443 http://127.0.0.1:8765";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=8443 off";
      TimeoutStartSec = "30s";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
