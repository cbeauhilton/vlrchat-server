{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.authentik;
in {
  options.services.vlr.authentik = {
    enable = mkEnableOption "Enable authentik auth service";
  };

  config = mkIf cfg.enable {
    # Create system user
    users.users.authentik = {
      isSystemUser = true;
      group = "authentik";
      home = "/var/lib/authentik";
    };
    users.groups.authentik = {};

    # Configure Authentik service
    services = {
      authentik = {
        enable = true;
        # Basic settings that don't need to be secret
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

      # Ensure PostgreSQL has the database and user
      postgresql = {
        ensureDatabases = ["authentik"];
        ensureUsers = [{
          name = "authentik";
          ensureDBOwnership = true;
        }];
      };

      # Basic nginx configuration
      nginx.virtualHosts."auth.vlr.chat" = {
        locations."/" = {
          proxyPass = "http://localhost:9000";
          proxyWebsockets = true;
        };
      };
    };
  };
} 