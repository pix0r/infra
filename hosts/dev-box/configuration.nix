# dev-box: one small NixOS box for Claude Code sessions, the brain orchestrator,
# and whatever Elixir apps get built. Edit, open a PR, merge — comin applies it
# on the box within about a minute. State lives under /data (persistent volume).
{ config, pkgs, pkgs-unstable, lib, ... }:
let
  githubUser = "pix0r";
  # https://github.com/pix0r.keys — paste new keys here; PR; comin applies.
  sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDM2wmrexoZ1vrZSFXkvmqZCE4+PzkMxNXM+2bYl8+MIg2UYozz/xF2LuCA4GZ+yUm4Yd2YPgOcrC70TuqWO+UtKuPQ+LLZ9T9NQ9x/u3XZ2vht4Ys31oqQ0HdaQb+4baoIRmARLF5OnY/FG/1saOq3qAL8y0q0Wf8WiCnFpsM1CRs34d44LOVExdQ4Avox8CCBA7JbLd4x/nORhqeP0id41j8Sm2v2TwtQP8baq9RPesMwUiJmGAsb5fmlPuD4vykcNPW5qigZgLrvQNEDDHz8uyDJTxKpNWL+Ires4DIPH1mrFXnWS+ERxOnpOuiscfO8+6sGMiBnYkYqNqBjZ5DzweMmXh11JthSKRhoEcsDMYbaZinE2oNIMRsmU2Z6x7Pbyl1By4W59I2b0j9/HA6WiF8pTRk183yWUMbLUnFNlO6tqhoJdP48LrIFgPhCXYfarR/ZsM9ofM4xihfRsv4z1p7Y3lLHRlvYjaMRGJ3jk6+hg/KIWDZ83LQV8xtVGZ8qp2/vcYCfI3+zEAE6TfPUFlqyuvG+gaJF3jqY8LZ5t56tNl0XXXARTRrGLR/AVZU/6/0UpdBTZ+hOB+NLhmZVnUKwT7sxgs5k4PqT2DLOsjJydfAWN2I1gOx02cvpUSctn49Jp5UEbTpLhBmkY5l0M4DDgq+llUn+zsthyanv3Q=="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCKtPwlhaemcTNrhWftQcjffnxc+nYZkREt++XmkAJh1aZGnd7uM94RrAMpmGKRoIPoPPhb2SRFfHI6nssIdXefOR6sQL7lcOqBwlGgLKXSxj9WlZNchOarZTw5FkkBF2i9HdmsbycS0YrrZDX1Ps5eCTaOQCYxetZnF99bQHqgb88zkRUbzJ2meVVo7Tl5Y+o7o6C8NsJz8/1C5rnpV/dNU27k3ddEFxOsdotF9nZw6iGUq5SBD7mzQUe66Fo7q3UZP57uugtQwAwQxpjvU0OU5z8A3tQnfTgPK0fwQGnL75cFXVbjj6do0yylvJPkyOW08QFscC5bG+dB+CbzpHZ+kIJoJsJnvn/MKcMnvgHkWbez5v4ah/LMsR6KqJn1WwNTAOPhIA/KFdyYOJSca0J6rBO6tGd7lEeuzazrpkgF4ww9DJms7kEFGOrvH2h66GXl5JQAasB69GoYiviC1s+2Ydlq1NBqpIav+DlPCG5XeKi8d/WzMXBT89vcA5B5ApiYadDx38C7yeYtZA+OQjTfXYQF7/c0StrdE//RoYWCiczqSvwBfkRXYjZZq5/9xYSOa7LU1UGP7BvqhU6Lwkz+bUzgjqllTaRXA3bPlmpSlO+SIJ/YQ07KBgaFqzOleJEED4faJ6HeCjln3xtnmTVEJOcTdIr2dbPTYrK7F2OvVQ=="
  ];
  beam = pkgs.beam.packages.erlang_27;
in
{
  networking.hostName = "dev-box"; # comin deploys nixosConfigurations.<hostName>
  time.timeZone = "UTC";
  system.stateVersion = "26.05"; # never change after first deploy

  # ---- GitOps: comin pulls main and switches ----------------------------------
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://github.com/${githubUser}/infra.git";
      branches.main.name = "main";
      # Optional: a testing-dev-box branch deploys to this box only (see comin docs).
    }];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "dev" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ---- Users -----------------------------------------------------------------
  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  users.users.dev = {
    isNormalUser = true;
    home = "/data/home/dev"; # on the persistent volume
    createHome = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = sshKeys;
  };
  security.sudo.wheelNeedsPassword = false;

  # ---- Network / SSH -----------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      MaxAuthTries = 3;
    };
  };
  services.fail2ban.enable = true;
  programs.mosh.enable = true; # opens UDP 60000-61000 in the NixOS firewall

  # Tailscale: `ssh dev@dev-box` and http://dev-box:4000 from any tailnet device.
  # One-time after first boot: `sudo tailscale up` and open the printed URL.
  # Its identity lives on /data so it survives server replacement.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  fileSystems."/var/lib/tailscale" = {
    device = "/data/tailscale";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/data" ];
  };
  systemd.tmpfiles.rules = [ "d /data/tailscale 0700 root root -" ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ config.services.tailscale.port ]; # 41641, direct peer connections
    trustedInterfaces = [ "tailscale0" ]; # everything (e.g. port 4000) open to the tailnet only
    # From the public internet only SSH + mosh; apps are reached over the tailnet.
  };

  # ---- Tooling -------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git gh tmux mosh ripgrep jq htop neovim curl tree
    beam.erlang beam.elixir_1_18
    pkgs-unstable.claude-code
  ];
  environment.variables.EDITOR = "nvim";

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux.conf; # ^A prefix, vi keys, base-index 1
  };

  virtualisation.docker = {
    enable = true;
    daemon.settings.data-root = "/data/docker"; # images/volumes survive rebuilds
  };

  # ---- Pattern: an Elixir release as a service ---------------------------------------
  # systemd.services.my-app = {
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network-online.target" ];
  #   serviceConfig = {
  #     User = "dev";
  #     WorkingDirectory = "/data/apps/my-app";
  #     ExecStart = "/data/apps/my-app/bin/my_app start";
  #     Restart = "always";
  #     EnvironmentFile = "/data/apps/my-app/.env"; # secrets stay on /data, never in git
  #   };
  # };
}
