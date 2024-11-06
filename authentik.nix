{ config, lib, pkgs, ... }: {
  # Configure PostgreSQL for authentik
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "authentik" ];
    ensureUsers = [{
      name = "authentik";
      ensureDBOwnership = true;
    }];
    settings = {
      listen_addresses = "127.0.0.1";
    };
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS         METHOD
      local   authentik       authentik                       trust
      host    authentik       authentik       127.0.0.1/32   trust
      host    authentik       authentik       ::1/128        trust
      local   all            all                             peer
    '';
  };

  # Configure Redis for Authentik
  services.redis.servers."authentik" = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
    unixSocket = "/run/redis-authentik/redis.sock";
    settings = {
      supervised = "systemd";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/data 0750 authentik authentik -"
    "d /var/lib/authentik/media 0750 authentik authentik -"
    "d /run/redis-authentik 0750 authentik authentik -"
  ];

  virtualisation.oci-containers.containers.authentik = {
    image = "ghcr.io/goauthentik/server:latest";
    environmentFiles = [ "/run/secrets/authentik/authentik-env" ];
    
    environment = {
      AUTHENTIK_POSTGRESQL__HOST = "127.0.0.1";
      AUTHENTIK_POSTGRESQL__USER = "authentik";
      AUTHENTIK_POSTGRESQL__NAME = "authentik";
      AUTHENTIK_REDIS__HOST = "127.0.0.1";
      AUTHENTIK_REDIS__PORT = "6379";
    };
    
    volumes = [
      "/var/lib/authentik/data:/data"
      "/var/lib/authentik/media:/media"
    ];

    dependsOn = [ "postgresql.service" "redis-authentik.service" ];

    user = "999:999";

    extraOptions = [
      "--network=host"
    ];
  };

  # Enable nginx and ACME for Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "beau@vlr.chat";
  };

  # Nginx reverse proxy configuration
  services.nginx.virtualHosts."auth.vlr.chat" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:9000";
      proxyWebsockets = true;
    };
  };

  # Add system user for authentik
  users.users.authentik = {
    isSystemUser = true;
    group = "authentik";
    home = "/var/lib/authentik";
  };

  users.groups.authentik = {};
} 