{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend;
in {
  imports = [
    ./flowise
    ./static
  ];

  options.services.vlr.backend = {
    enable = mkEnableOption "Enable VLR backend services";
  };

  config = mkIf cfg.enable {
    # Enable individual services if not explicitly disabled
    services.vlr.backend.flowise.enable = mkDefault false;
    services.vlr.backend.static.enable = mkDefault true;

    # Common Traefik configuration
    services.traefik.dynamicConfigOptions.http = {
      # Services
      services = {
        flowise.loadBalancer.servers = [{
          url = "http://localhost:3000";
        }];
        static.loadBalancer.servers = [{
          url = "http://localhost:3001";
        }];
      };

      # Routers
      routers = {
        flowise = {
          entryPoints = ["websecure"];
          rule = "Host(`flowise.vlr.chat`)";
          service = "flowise";
          middlewares = ["authentik"];
          tls.certResolver = "letsencrypt";
        };
        static = {
          entryPoints = ["websecure"];
          rule = "Host(`static.vlr.chat`)";
          service = "static";
          middlewares = ["authentik"];
          tls.certResolver = "letsencrypt";
        };
      };
    };
  };
}

