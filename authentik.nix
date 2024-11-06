{ config, lib, pkgs, ... }:
with lib; {
  imports = [ ./postgresql.nix ];

  # System user and group
  users.users.authentik = {
    isSystemUser = true;
    group = "authentik";
    home = "/var/lib/authentik";
  };
  users.groups.authentik = {};

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
    # For development, we'll create a basic environment file
    environmentFile = "/var/lib/authentik/authentik.env";
  };

  # Create the environment file with basic settings
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik 0750 authentik authentik -"
    "f /var/lib/authentik/authentik.env 0640 authentik authentik - AUTHENTIK_SECRET_KEY=development_secret_key\nAUTHENTIK_POSTGRESQL__HOST=localhost\nAUTHENTIK_POSTGRESQL__USER=authentik\nAUTHENTIK_POSTGRESQL__NAME=authentik\nAUTHENTIK_POSTGRESQL__PASSWORD=authentik"
  ];
} 