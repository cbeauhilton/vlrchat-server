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

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;

      # Add self-signed cert configuration
      sslCertificate = "/run/secrets/nginx-cert.pem";
      sslCertificateKey = "/run/secrets/nginx-key.pem";

      virtualHosts = {
        "auth.vlr.chat" = {
          serverName = "auth.vlr.chat";
          forceSSL = true;
          # Remove enableACME = true;
          useACMEHost = false;
          sslCertificate = "/run/secrets/nginx-cert.pem";
          sslCertificateKey = "/run/secrets/nginx-key.pem";
          extraConfig = ''
            proxy_headers_hash_max_size 512;
            proxy_headers_hash_bucket_size 64;
          '';
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:9000";
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
            "/ws" = {
              proxyPass = "http://127.0.0.1:9000";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
              '';
            };
          };
        };
        
        "vlr.chat" = {
          serverName = "vlr.chat";
          locations."/" = {
            return = "404";
          };
        };
      };
    };
  };
}
