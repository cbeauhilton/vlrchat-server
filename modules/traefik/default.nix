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

        certificatesResolvers = {
          default = {
            acme = {
              email = "beau@beauhilton.com";
              storage = "/var/lib/traefik/acme.json";
              httpChallenge.entryPoint = "web";
            };
          };
        };
      };

      dynamicConfigOptions = {
        http = {
          middlewares = {
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
          routers = {
            authentik = {
              rule = "Host(`auth.vlr.chat`)";
              service = "auth";
              entryPoints = ["websecure"];
              tls = {
                certResolver = "default";
              };
            };
            authentik-outpost = {
              rule = "Host(`auth.vlr.chat`) && PathPrefix(`/outpost.goauthentik.io/`)";
              service = "auth";
              entryPoints = ["websecure"];
              tls = {
                certResolver = "default";
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
        };
      };
    };

    systemd.services.traefik.serviceConfig = {
      StateDirectory = "traefik";
    };
  };
}
