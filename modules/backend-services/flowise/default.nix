{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend.flowise;
  
  # Create a derivation for Flowise
  flowise = pkgs.buildNpmPackage {
    pname = "flowise";
    version = "2.1.3";
    
    src = pkgs.fetchFromGitHub {
      owner = "FlowiseAI";
      repo = "Flowise";
      rev = "flowise@2.1.3";
      sha256 = "sha256-3ZqvFmfMZMCEoP7rrtsqWz+s2xKOUTz1SkETlnDuRzk=";
    };

    postPatch = ''
      ${pkgs.nodejs_18}/bin/npm i --package-lock-only
    '';

    npmDepsHash = "";

    nativeBuildInputs = with pkgs; [ nodejs_18 ];
    buildInputs = with pkgs; [ nodejs_18 ];

    makeCacheWritable = true;
    npmFlags = [ "--legacy-peer-deps" ];
    npmInstallFlags = [ "--only=production" ];
  };

in {
  config = mkIf cfg.enable {
    systemd.services.flowise = {
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
  };
}
