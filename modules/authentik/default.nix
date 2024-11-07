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
      environmentFile = "/run/secrets/authentik-env";
      settings = {
        disable_startup_analytics = true;
        avatars = "initials";
        email = {
          # host = "smtp.mailgun.org";
          # port = 587;
          # use_tls = true;
          # use_ssl = false;
          # from = "authentik@yourdomain.com";
        };
        listen.http = {
          host = "0.0.0.0";
          port = 9000;
        };
        listen.https = {
          host = "0.0.0.0";
          port = 9443;
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

    systemd.tmpfiles.rules = [
      "d /run/secrets 0755 root root"
    ];
  };
}
