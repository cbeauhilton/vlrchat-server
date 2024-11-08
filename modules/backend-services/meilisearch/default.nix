{ config, lib, pkgs, ... }:

with lib; let
  cfg = config.services.vlr.backend.meilisearch;
in {
  options.services.vlr.backend.meilisearch = {
    port = mkOption {
      type = types.port;
      default = 7700;
      description = "Port on which Meilisearch will listen";
    };

    environment = mkOption {
      type = types.enum [ "development" "production" ];
      default = "development";
      description = "Defines the running environment of MeiliSearch";
    };

    logLevel = mkOption {
      type = types.str;
      default = "INFO";
      description = "Log level for Meilisearch (ERROR, WARN, INFO, DEBUG)";
    };
  };

  config = mkIf cfg.enable {
    services.meilisearch = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = cfg.port;
      environment = cfg.environment;
      logLevel = cfg.logLevel;
    };

    # Create meilisearch user and group
    users.users.meilisearch = {
      isSystemUser = true;
      group = "meilisearch";
      home = "/var/lib/meilisearch";
      createHome = true;
    };
    users.groups.meilisearch = {};

    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/meilisearch 0750 meilisearch meilisearch -"
    ];
  };
}
