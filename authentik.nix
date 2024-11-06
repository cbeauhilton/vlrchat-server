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
} 