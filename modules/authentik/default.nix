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
      "d /var/lib/nginx/certs 0750 nginx nginx -"
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts = {
        "auth.vlr.chat" = {
          serverName = "auth.vlr.chat";
          forceSSL = true;
          
          # Update certificate paths
          sslCertificate = "/var/lib/nginx/certs/cert.pem";
          sslCertificateKey = "/var/lib/nginx/certs/key.pem";
          
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
                proxy_set_header X-Forwarded-Port $server_port;
                proxy_set_header X-Forwarded-Host $host;
                
                # Additional settings for better compatibility
                proxy_redirect off;
                proxy_buffering off;
                proxy_read_timeout 90s;
                proxy_connect_timeout 90s;
                proxy_send_timeout 90s;
              '';
            };
            "/outpost.goauthentik.io/" = {
              # The embedded outpost runs on port 9443
              proxyPass = "http://127.0.0.1:9443";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Port $server_port;
                proxy_set_header X-Forwarded-Host $host;
                
                # Additional headers for Authentik outpost
                proxy_set_header X-authentik-username $remote_user;
                proxy_set_header X-authentik-groups $upstream_http_x_authentik_groups;
                proxy_set_header X-authentik-email $upstream_http_x_authentik_email;
                proxy_set_header X-authentik-name $upstream_http_x_authentik_name;
                proxy_set_header X-authentik-uid $upstream_http_x_authentik_uid;
                proxy_set_header X-authentik-jwt $upstream_http_x_authentik_jwt;
                proxy_set_header X-authentik-meta-jwks $upstream_http_x_authentik_meta_jwks;
                proxy_set_header X-authentik-meta-outpost $upstream_http_x_authentik_meta_outpost;
                proxy_set_header X-authentik-meta-provider $upstream_http_x_authentik_meta_provider;
                proxy_set_header X-authentik-meta-app $upstream_http_x_authentik_meta_app;
                proxy_set_header X-authentik-meta-version $upstream_http_x_authentik_meta_version;
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
      };
    };
  };
}
