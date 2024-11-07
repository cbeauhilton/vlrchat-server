{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend;
in {
  options.services.vlr.backend = {
    enable = mkEnableOption "Enable VLR backend services";
    flowise = {
      enable = mkEnableOption "Enable Flowise AI";
    #   credentials = { # using authentik, single flowise user, at least for now
    #     username = mkOption {
    #       type = types.str;
    #       default = "admin";
    #       description = "Flowise admin username";
    #     };
    #     password = mkOption {
    #       type = types.str;
    #       default = "changeme123";
    #       description = "Flowise admin password";
    #     };
    #   };
    };
    # We can add more backend services here later
  };

  config = mkIf cfg.enable {
    # Create the flowise data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/flowise 0750 root root -"
    ];

    # Flowise container configuration
    virtualisation.oci-containers.containers = mkIf cfg.flowise.enable {
      flowise = {
        image = "flowiseai/flowise:latest";
        ports = [ "3000:3000" ];
        environment = {
        #   FLOWISE_USERNAME = cfg.flowise.credentials.username;
        #   FLOWISE_PASSWORD = cfg.flowise.credentials.password;
          PORT = "3000";
          DISABLE_FLOWISE_TELEMETRY = "true";  # Optional: disable telemetry
        };
        volumes = [
          "/var/lib/flowise:/root/.flowise"
        ];
        extraOptions = [
          "--network=host"
        ];
      };
    };

    # Traefik configuration for all backend services
    services.traefik.dynamicConfigOptions.http = {
      services = mkMerge [
        (mkIf cfg.flowise.enable {
          flowise.loadBalancer.servers = [{
            url = "http://localhost:3000";
          }];
        })
        # Add more services here as needed
      ];

      routers = mkMerge [
        (mkIf cfg.flowise.enable {
          flowise = {
            entryPoints = ["websecure"];
            rule = "Host(`flowise.vlr.chat`)";
            service = "flowise";
            middlewares = ["authentik"];
            tls.certResolver = "letsencrypt";
          };
        })
        # Add more routers here as needed
      ];
    };
  };
}
