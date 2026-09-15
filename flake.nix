{
  description = "pix0r infra — NixOS hosts (installed by nixos-anywhere, kept in sync by comin from main)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, comin, disko, ... }:
    let
      system = "x86_64-linux";
      # Only for packages that move too fast for the release channel (claude-code).
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
      };
    in
    {
      nixosConfigurations.dev-box = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          comin.nixosModules.comin
          disko.nixosModules.disko
          ./hosts/dev-box/disko.nix
          ./hosts/dev-box/hardware.nix
          ./hosts/dev-box/configuration.nix
        ];
      };
    };
}
