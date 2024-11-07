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

      # Add proxy hash settings to resolve the warning
      appendConfig = ''
        proxy_headers_hash_max_size 1024;
        proxy_headers_hash_bucket_size 128;
      '';

      virtualHosts = {
        "auth.vlr.chat" = {
          serverName = "auth.vlr.chat";
          locations."/" = {
            proxyPass = "http://127.0.0.1:9000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_buffering off;
              proxy_set_header Host $http_host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $http_host;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection $connection_upgrade;
              proxy_read_timeout 90s;
              proxy_connect_timeout 90s;
              proxy_send_timeout 90s;
            '';
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
