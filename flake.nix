{
  description = "Patched Google Antigravity 2.0 (Desktop) and CLI (agy) Flake with Open Antigravity eligibility bypass";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          default = agy;
          agy = pkgs.callPackage ./pkgs/agy { };
          antigravity = pkgs.callPackage ./pkgs/antigravity { };
        });

      apps = forAllSystems (system: rec {
        default = agy;
        agy = {
          type = "app";
          program = "${self.packages.${system}.agy}/bin/agy";
        };
        antigravity = {
          type = "app";
          program = "${self.packages.${system}.antigravity}/bin/antigravity";
        };
        antigravity-personal = {
          type = "app";
          program = "${self.packages.${system}.antigravity}/bin/antigravity-personal";
        };
        antigravity-workspace = {
          type = "app";
          program = "${self.packages.${system}.antigravity}/bin/antigravity-workspace";
        };
      });

      overlays.default = final: prev: {
        agy = final.callPackage ./pkgs/agy { };
        antigravity = final.callPackage ./pkgs/antigravity { };
      };

      nixosModules = {
        default = import ./modules/nixos.nix;
        antigravity = import ./modules/nixos.nix;
      };
    };
}
