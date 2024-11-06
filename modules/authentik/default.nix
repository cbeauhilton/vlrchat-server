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
      # For testing, we'll create a basic environment file
      environmentFile = "/run/secrets/authentik-env";
      settings = {
        disable_startup_analytics = true;
        avatars = "initials";
        email = {
          host = "smtp.mailgun.org";
          port = 587;
          use_tls = true;
          use_ssl = false;
          from = "authentik@yourdomain.com";
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

    # Add systemd tmpfile to create the secrets directory
    systemd.tmpfiles.rules = [
      "d /run/secrets 0755 root root"
    ];
  };
}
