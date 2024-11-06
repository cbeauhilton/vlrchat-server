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
      error_reporting = {
        enabled = false;
      };
    };
  };
} 