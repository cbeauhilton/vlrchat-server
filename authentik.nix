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

  # Container configuration
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      authentik-postgresql = {
        image = "docker.io/library/postgres:16-alpine";
        environment = {
          POSTGRES_PASSWORD = "$(<\"/var/lib/authentik/secrets/pg_pass\")";
          POSTGRES_USER = "authentik";
          POSTGRES_DB = "authentik";
        };
        volumes = [
          "authentik-database:/var/lib/postgresql/data"
        ];
      };

      authentik-redis = {
        image = "docker.io/library/redis:alpine";
        cmd = ["--save" "60" "1" "--loglevel" "warning"];
        volumes = [
          "authentik-redis:/data"
        ];
      };

      authentik-server = {
        image = "ghcr.io/goauthentik/server:2024.10.1";
        cmd = ["server"];
        environment = {
          AUTHENTIK_REDIS__HOST = "localhost";
          AUTHENTIK_POSTGRESQL__HOST = "localhost";
          AUTHENTIK_POSTGRESQL__USER = "authentik";
          AUTHENTIK_POSTGRESQL__NAME = "authentik";
          AUTHENTIK_POSTGRESQL__PASSWORD = "$(<\"/var/lib/authentik/secrets/pg_pass\")";
          AUTHENTIK_SECRET_KEY = "$(<\"/var/lib/authentik/secrets/authentik_secret\")";
        };
        volumes = [
          "/var/lib/authentik/media:/media"
          "/var/lib/authentik/templates:/templates"
        ];
        dependsOn = [ "authentik-postgresql" "authentik-redis" ];
        extraOptions = [
          "--network=host"
        ];
      };

      authentik-worker = {
        image = "ghcr.io/goauthentik/server:2024.10.1";
        cmd = ["worker"];
        environment = {
          AUTHENTIK_REDIS__HOST = "localhost";
          AUTHENTIK_POSTGRESQL__HOST = "localhost";
          AUTHENTIK_POSTGRESQL__USER = "authentik";
          AUTHENTIK_POSTGRESQL__NAME = "authentik";
          AUTHENTIK_POSTGRESQL__PASSWORD = "$(<\"/var/lib/authentik/secrets/pg_pass\")";
          AUTHENTIK_SECRET_KEY = "$(<\"/var/lib/authentik/secrets/authentik_secret\")";
        };
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
          "/var/lib/authentik/media:/media"
          "/var/lib/authentik/certs:/certs"
          "/var/lib/authentik/templates:/templates"
        ];
        dependsOn = [ "authentik-postgresql" "authentik-redis" ];
        extraOptions = [
          "--network=host"
          "--user=root"
        ];
      };
    };
  };

  # HTTPS configuration
#   security.acme = {
#     acceptTerms = true;
#     defaults = {
#       email = "beau@vlr.chat";
#       server = "https://acme-staging-v02.api.letsencrypt.org/directory";
#       webroot = "/var/lib/acme/acme-challenge";
#       group = "nginx";
#     };
#   };

  # Nginx reverse proxy
  services.nginx.virtualHosts."auth.vlr.chat" = {
    # enableACME = true;
    forceSSL = true;
    # # Modify the ACME challenge location
    # locations."/.well-known/acme-challenge" = {
    #   root = "/var/lib/acme/acme-challenge";
    #   extraConfig = ''
    #     allow all;
    #     auth_basic off;
    #   '';
    # };
    locations."/" = {
      proxyPass = "http://localhost:9000";
      proxyWebsockets = true;
    };
  };
} 