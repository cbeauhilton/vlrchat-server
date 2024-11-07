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
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };
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
        certificatesResolvers.default = {
          acme = {
            email = "beau@beauhilton.com";
            storage = "/var/lib/traefik/acme.json";
            httpChallenge.entryPoint = "web";
          };
        };
      };
      dynamicConfigOptions = {
        http = {
          middlewares = {
            authentik-forward-auth = {
              forwardAuth = {
                address = "http://127.0.0.1:9000/outpost.goauthentik.io/auth/traefik";
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
                ];
              };
            };
          };
          routers = {
            authentik = {
              rule = "Host(`auth.vlr.chat`)";
              service = "authentik";
              entryPoints = ["websecure"];
              tls = {
                certResolver = "default";
              };
            };
          };
          services.authentik.loadBalancer = {
            servers = [{
              url = "http://127.0.0.1:9000";
            }];
            passHostHeader = true;
          };
        };
      };
    };

    # Ensure directories exist
    systemd.tmpfiles.rules = [
      "d /var/lib/traefik 0750 traefik traefik -"
    ];
  };
}
