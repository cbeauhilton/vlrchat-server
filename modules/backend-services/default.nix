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
    systemd.services.flowise = mkIf cfg.flowise.enable {
      description = "Flowise AI";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = "3000";
        HOME = "/var/lib/flowise";
      };
      serviceConfig = {
        Type = "simple";
        User = "flowise";
        Group = "flowise";
        ExecStart = "${pkgs.nodejs_18}/bin/node ${pkgs.nodePackages.flowise}/bin/flowise start";
        Restart = "always";
        RestartSec = "10";
        WorkingDirectory = "/var/lib/flowise";
      };
    };

    # Create flowise user and group
    users.users.flowise = {
      isSystemUser = true;
      group = "flowise";
      home = "/var/lib/flowise";
      createHome = true;
    };
    users.groups.flowise = {};

    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/flowise 0750 flowise flowise -"
    ];

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

