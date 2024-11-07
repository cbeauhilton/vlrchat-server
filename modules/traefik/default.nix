{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.traefik;
  
  # Script to generate self-signed certificates
  generateCerts = pkgs.writeShellScript "generate-traefik-certs" ''
    # Exit on any error
    set -e

    CERT_DIR="/var/lib/traefik"
    CERT_FILE="$CERT_DIR/cert.pem"
    KEY_FILE="$CERT_DIR/key.pem"

    # Only generate if certificates don't exist
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
      echo "Generating self-signed certificates for Traefik..."
      
      # Generate self-signed certificate
      ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=auth.vlr.chat" \
        -addext "subjectAltName = DNS:auth.vlr.chat"

      # Set proper permissions
      chown traefik:traefik "$CERT_FILE" "$KEY_FILE"
      chmod 644 "$CERT_FILE"
      chmod 600 "$KEY_FILE"
      
      echo "✅ Self-signed certificates generated successfully"
    else
      echo "Certificates already exist, skipping generation"
    fi
  '';

in {
  options.services.vlr.traefik = {
    enable = mkEnableOption "Enable traefik";
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;
      staticConfigOptions = {
        entryPoints = {
          web = {
            address = ":80";
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
            };
          };
          websecure = {
            address = ":443";
          };
        };
        
        log = {
          level = "DEBUG";
        };

        # For development, use static certificates instead of Let's Encrypt
        tls = {
          certificates = [{
            certFile = "/var/lib/traefik/cert.pem";
            keyFile = "/var/lib/traefik/key.pem";
          }];
          options = {
            default = {
              insecureSkipVerify = true;  # For development only
            };
          };
        };
      };

      dynamicConfigOptions = {
        http = {
          middlewares = {
            security-headers = {
              headers = {
                stsSeconds = 31536000
                stsIncludeSubdomains = true
                contentTypeNosniff = true
                xFrameOptions = "DENY"
                referrerPolicy = "strict-origin-when-cross-origin"
              };
            };
            authentik = {
              forwardAuth = {
                address = "https://localhost:9443/outpost.goauthentik.io/auth/traefik";
                tls.insecureSkipVerify = true;
                trustForwardHeader = true;
                authResponseHeaders = [
                  "X-authentik-username"
                  "X-authentik-groups"
                  "X-authentik-email"
                  "X-authentik-name"
                  "X-authentik-uid"
                  "X-authentik-jwt"
                  "X-authentik-meta-jwks"
                  "X-authentik-meta-outpost"
                  "X-authentik-meta-provider"
                  "X-authentik-meta-app"
                  "X-authentik-meta-version"
                ];
              };
            };
          };
          services = {
            auth = {
              loadBalancer = {
                servers = [{
                  url = "http://localhost:9000";
                }];
                passHostHeader = true;
              };
            };
          };
          routers = {
            auth = {
              rule = "Host(`auth.vlr.chat`) || PathPrefix(`/outpost.goauthentik.io/`)";
              service = "auth";
              entryPoints = ["websecure"];
              middlewares = ["security-headers"];
              tls = {};  # Use static certificates instead of certResolver
            };
          };
        };
      };
    };

    # Ensure the certificate directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/traefik 0750 traefik traefik -"
    ];

    # Modify the Traefik service to generate certificates before starting
    systemd.services.traefik = {
      serviceConfig = {
        StateDirectory = "traefik";
        ReadWritePaths = [ "/var/lib/traefik" ];
      };
      preStart = ''
        ${generateCerts}
      '';
    };
  };
}
