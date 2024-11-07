{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.traefik;
  
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

        # Let's Encrypt configuration
        certificatesResolvers.letsencrypt.acme = {
          email = "beau@beauhilton.com";  # Replace with your email
          storage = "/var/lib/traefik/acme.json";
          httpChallenge.entryPoint = "web";
        };
      };

      dynamicConfigOptions = {
        http = {
          middlewares = {
            # security-headers = {
            #   headers = {
            #     stsSeconds = 31536000;
            #     stsIncludeSubdomains = true;
            #     contentTypeNosniff = true;
            #     xFrameOptions = "DENY";
            #     referrerPolicy = "strict-origin-when-cross-origin";
            #   };
            # };
            authentik = {
              forwardAuth = {
                address = "https://auth.vlr.chat/outpost.goauthentik.io/auth/traefik";
                tls.insecureSkipVerify = false;
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
            authentik = {
              loadBalancer = {
                servers = [{
                  url = "http://localhost:9000";
                }];
              };
            };
          };
          routers = {
            authentik = {
              entryPoints = ["websecure"];
              rule = "Host(`auth.vlr.chat`) || PathPrefix(`/outpost.goauthentik.io/`)";
              service = "authentik";
              tls = {
                certResolver = "letsencrypt";
              };
            };
          };
        };
      };
    };

    # Ensure the certificate directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/traefik 0750 traefik traefik -"
    ];

    systemd.services.traefik = {
      serviceConfig = {
        StateDirectory = "traefik";
        ReadWritePaths = [ "/var/lib/traefik" ];
      };
      after = [ "static.service" "flowise.service" ];
      # requires = [ "static.service" ];  # Can specify required services here
    };
  };
}
