{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend.meilisearch;

  # Helper function to convert a Nix attribute set to environment variables
  toEnvFormat = attrs: concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${toString v}") attrs);
in {
  options.services.vlr.backend.meilisearch = {
    port = mkOption {
      type = types.port;
      default = 7700;
      description = "Port on which Meilisearch will listen";
    };

    extraConfig = mkOption {
      type = with types; attrsOf (oneOf [ bool int str ]);
      default = {};
      example = literalExpression ''
        {
          MEILI_MAX_INDEXING_MEMORY = "2 GiB";
          MEILI_MAX_INDEXING_THREADS = 4;
        }
      '';
      description = "Additional Meilisearch configuration options";
    };
  };

  config = mkIf cfg.enable {
    # Enable the base meilisearch service
    services.meilisearch = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = cfg.port;
      environment = "development";
      environmentVariables = 
        # Set default values here
        {
          MEILI_EXPERIMENTAL_ENABLE_METRICS = "true";
          MEILI_EXPERIMENTAL_VECTOR_STORE = "true";
          MEILI_MAX_INDEXING_MEMORY = "2 GiB";
          MEILI_LOG_LEVEL = "INFO";
        } // cfg.extraConfig;
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
