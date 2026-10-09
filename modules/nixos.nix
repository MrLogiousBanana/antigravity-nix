{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.antigravity;
in
{
  options.programs.antigravity = {
    enable = mkEnableOption "Google Antigravity suite (Desktop and CLI)";

    enableCLI = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the patched Antigravity CLI ('agy').";
    };

    enableDesktop = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the patched Antigravity 2.0 Desktop app with profile launcher.";
    };

    cliPackage = mkOption {
      type = types.package;
      default = pkgs.agy or (pkgs.callPackage ../pkgs/agy { });
      description = "Antigravity CLI package to install.";
    };

    desktopPackage = mkOption {
      type = types.package;
      default = pkgs.antigravity or (pkgs.callPackage ../pkgs/antigravity { });
      description = "Antigravity Desktop package to install.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      (optional cfg.enableCLI cfg.cliPackage) ++
      (optional cfg.enableDesktop cfg.desktopPackage);

    # Ensure udev / D-Bus and secret service requirements are satisfied
    services.dbus.enable = mkDefault true;
  };
}
