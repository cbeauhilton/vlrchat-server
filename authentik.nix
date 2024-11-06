{ config, lib, pkgs, ... }: {
  # System user and group
  users.users.authentik = {
    isSystemUser = true;
    group = "authentik";
    home = "/var/lib/authentik";
  };
  users.groups.authentik = {};

  # Directory structure
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/media 0750 authentik authentik -"
    "d /var/lib/authentik/certs 0750 authentik authentik -"
    "d /var/lib/authentik/templates 0750 authentik authentik -"
  ];

  # Enable Authentik service
  services.authentik = {
    enable = true;
    # Basic settings
    settings = {
      email = {
        host = "localhost";
        port = 25;
        username = "";
        password = "";
        use_tls = false;
        use_ssl = false;
        from = "authentik@localhost";
      };
      disable_startup_analytics = true;
      disable_update_check = true;
      error_reporting.enabled = false;
    };

    # Add environment configuration
    environmentFile = "/var/lib/authentik/authentik.env";
  };

  # Create basic environment file
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik 0750 authentik authentik -"
    "f /var/lib/authentik/authentik.env 0640 authentik authentik - AUTHENTIK_SECRET_KEY=yoursecretkeyhere\nAUTHENTIK_POSTGRESQL__HOST=localhost\nAUTHENTIK_POSTGRESQL__USER=authentik\nAUTHENTIK_POSTGRESQL__NAME=authentik\nAUTHENTIK_POSTGRESQL__PASSWORD=authentik"
  ];

  # Enable and configure PostgreSQL
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "authentik" ];
    ensureUsers = [
      {
        name = "authentik";
        ensurePermissions = {
          "DATABASE authentik" = "ALL PRIVILEGES";
        };
      }
    ];
  };
} 