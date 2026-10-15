# Side-by-side LiveView comparison; the Python service remains the baseline.
{ config, pkgs, ... }:
let
  root = "/data/lifedata/live";
  revision = "52d5b761d9a82be2c173f474e92db38a91298947";
  # Both services must read the same immutable SQLite snapshot for comparison.
  index = config.systemd.services.personal-search.environment.SEARCH_INDEX;
  provision = pkgs.writeShellScript "personal-search-live-provision"
    (builtins.readFile ./personal-search-live-provision.sh);
  launch = pkgs.writeShellScript "personal-search-live" ''
    set -euo pipefail
    export PHX_HOST="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -er '.Self.DNSName | select(length > 0) | rtrimstr(".")')"
    exec ${root}/packages/${revision}/bin/personal_search_live start
  '';
in {
  systemd.tmpfiles.rules = map (dir: "d ${root}${dir} 0700 dev users -")
    [ "" "/releases" "/packages" "/cache" ];

  systemd.services.personal-search-live-prepare = {
    description = "Build pinned private LiveView search application";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "personal-search-prepare.service" ];
    requires = [ "personal-search-prepare.service" ];
    before = [ "personal-search-live.service" ];
    partOf = [ "personal-search-live.service" ];
    unitConfig.RequiresMountsFor = root;
    path = [ pkgs.git pkgs.coreutils pkgs.nix pkgs.openssl ];
    environment = {
      HOME = "/data/home/dev";
      XDG_CACHE_HOME = "${root}/cache";
      GH_CONFIG_DIR = "/data/home/dev/.config/gh";
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "credential.helper";
      GIT_CONFIG_VALUE_0 = "!${pkgs.gh}/bin/gh auth git-credential";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "dev";
      Group = "users";
      ExecStart = "${provision} ${root} ${revision} ${pkgs.path}";
      TimeoutStartSec = "20min";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ root ];
      InaccessiblePaths = [ "/data/lifedata/archive" ];
    };
  };

  systemd.services.personal-search-live = {
    description = "Private LiveView and Ash personal search comparison";
    wantedBy = [ "multi-user.target" ];
    wants = [ "personal-search-live-https.service" ];
    requires = [ "personal-search-live-prepare.service" "tailscaled.service" ];
    after = [ "personal-search-live-prepare.service" "tailscaled.service" ];
    unitConfig.RequiresMountsFor = root;
    environment = {
      SEARCH_INDEX = index;
      SECRET_KEY_BASE_FILE = "${root}/secret-key-base";
      PORT = "8767";
      RELEASE_DISTRIBUTION = "none";
      RELEASE_COOKIE = "unused-distribution-disabled"; # Required by the release launcher; no distributed node.
      ELIXIR_ERL_OPTIONS = "+S 4:4";
      ERL_CRASH_DUMP = "/dev/null";
    };
    serviceConfig = {
      User = "dev";
      Group = "users";
      ExecStart = launch;
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      InaccessiblePaths = [ "/data/lifedata/archive" "/data/home/dev" "${root}/releases" ];
      MemoryMax = "768M";
    };
  };

  systemd.services.personal-search-live-https = {
    description = "Private Tailscale HTTPS for LiveView search";
    wantedBy = [ "multi-user.target" ];
    requires = [ "tailscaled.service" "personal-search-live.service" ];
    after = [ "tailscaled.service" "personal-search-live.service" ];
    partOf = [ "personal-search-live.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --bg --https=8444 http://127.0.0.1:8767";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=8444 off";
      TimeoutStartSec = "30s";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
