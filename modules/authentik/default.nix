{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.authentik;
in {
  options.services.vlr.authentik = {
    enable = mkEnableOption "Enable authentik auth service";
  };

  config = mkIf cfg.enable {
    services.authentik = {
      enable = true;
      settings = {
        disable_startup_analytics = true;
        avatars = "initials";
        email = {
          host = "localhost";
          port = 25;
          use_tls = false;
          use_ssl = false;
          from = "authentik@localhost";
        };
      };
    };

    services.postgresql = {
      ensureDatabases = ["authentik"];
      ensureUsers = [{
        name = "authentik";
        ensureDBOwnership = true;
      }];
    };
  };
}
