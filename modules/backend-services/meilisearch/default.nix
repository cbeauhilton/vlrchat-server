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

    # Add systemd service to enable experimental features
    systemd.services.meilisearch-experimental = {
      description = "Enable Meilisearch experimental features";
      after = [ "meilisearch.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          curl = "${pkgs.curl}/bin/curl";
          script = pkgs.writeScript "enable-experimental" ''
            #!${pkgs.bash}/bin/bash
            sleep 5  # Wait for Meilisearch to be fully ready
            ${curl} -X PATCH 'http://127.0.0.1:${toString cfg.port}/experimental-features/' \
              -H 'Content-Type: application/json' \
              --data-binary '{
                "metrics": true,
                "vectorStore": true,
              }'
          '';
        in "${script}";
      };
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
