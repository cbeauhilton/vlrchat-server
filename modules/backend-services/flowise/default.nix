{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend.flowise;
in {
  config = mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.flowise = {
        image = "flowiseai/flowise:latest";
        autoStart = true;
        environment = {
          PORT = toString cfg.port;
          FLOWISE_USERNAME = cfg.username;
          FLOWISE_PASSWORD = cfg.password;
          CORS_ORIGINS = cfg.corsOrigins;
          IFRAME_ORIGINS = cfg.iframeOrigins;
          DATABASE_PATH = "/root/.flowise/database.sqlite";
          APIKEY_PATH = "/root/.flowise/apikeys.json";
          SECRETKEY_PATH = "/root/.flowise/secrets.json";
          LOG_PATH = "/root/.flowise/logs";
          BLOB_STORAGE_PATH = "/root/.flowise/storage";
        };
        volumes = [
          "/var/lib/flowise:/root/.flowise"
        ];
        ports = [
          "${toString cfg.port}:${toString cfg.port}"
        ];
        extraOptions = [
          "--network=host"
        ];
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
