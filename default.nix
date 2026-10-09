{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

{
  agy = pkgs.callPackage ./pkgs/agy { };
  antigravity = pkgs.callPackage ./pkgs/antigravity { };
}
