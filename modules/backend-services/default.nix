{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend;
  
  # Create a derivation for Flowise
  flowise = pkgs.buildNpmPackage {
    pname = "flowise";
    version = "2.1.3";  # Update this to the version you want
    
    src = pkgs.fetchFromGitHub {
      owner = "FlowiseAI";
      repo = "Flowise";
      rev = "2.1.3";  # Use the same version as above
      sha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";  # You'll need to replace this
    };

    npmDepsHash = "sha256-YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY";  # You'll need to replace this

    buildInputs = with pkgs; [
      nodejs_18
    ];

    makeCacheWritable = true;
    npmFlags = [ "--legacy-peer-deps" ];

    # Skip some steps that might not be necessary
    npmInstallFlags = [ "--only=production" ];
  };

in {
  options.services.vlr.backend = {
    enable = mkEnableOption "Enable VLR backend services";
    flowise = {
      enable = mkEnableOption "Enable Flowise AI";
    };
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
        ExecStart = "${pkgs.nodejs_18}/bin/node ${flowise}/bin/flowise start";
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

    # Traefik configuration
    services.traefik.dynamicConfigOptions.http = {
      services = mkMerge [
        (mkIf cfg.flowise.enable {
          flowise.loadBalancer.servers = [{
            url = "http://localhost:3000";
          }];
        })
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
      ];
    };
  };
}

