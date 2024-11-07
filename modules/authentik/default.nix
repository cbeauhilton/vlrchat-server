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

    # Open required ports in the firewall
    networking.firewall = {
      allowedTCPPorts = [ 80 443 ];
    };

    # Configure Traefik for Authentik
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
        api = {
          dashboard = true;
          insecure = true;
        };
        providers.file = {
          directory = "/etc/traefik/dynamic";
          watch = true;
        };
      };
      dynamicConfigOptions = {
        http = {
          routers = {
            authentik = {
              rule = "Host(`auth.vlr.chat`)";
              service = "authentik";
              entryPoints = ["websecure"];
              tls = {
                certResolver = "default";
              };
            };
            authentik-outpost = {
              rule = "Host(`auth.vlr.chat`) && PathPrefix(`/outpost.goauthentik.io/`)";
              service = "authentik-outpost";
              entryPoints = ["websecure"];
              tls = {
                certResolver = "default";
              };
            };
          };
          services = {
            authentik = {
              loadBalancer = {
                servers = [{
                  url = "http://127.0.0.1:9000";
                }];
                passHostHeader = true;
              };
            };
            authentik-outpost = {
              loadBalancer = {
                servers = [{
                  url = "http://127.0.0.1:9443";
                }];
                passHostHeader = true;
              };
            };
          };
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
        };
      };
    };
  };
}
