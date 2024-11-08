{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend;
  
  # Helper function to create a standard service configuration
  mkServiceConfig = name: {
    enable ? false,
    port ? null,
    host ? "127.0.0.1",
    middlewares ? ["authentik"],
  }: {
    inherit enable port host middlewares;
    url = "http://${host}:${toString port}";
    subdomain = "${name}.vlr.chat";
  };

  # Service definitions
  services = {
    flowise = mkServiceConfig "flowise" {
      enable = cfg.flowise.enable;
      port = 3000;
    };
    static = mkServiceConfig "static" {
      enable = cfg.static.enable;
      port = 3001;
    };
    meilisearch = mkServiceConfig "meilisearch" {
      enable = cfg.meilisearch.enable;
      port = 7700;
    };
    # Add new services here following the same pattern
  };

  # Generate Traefik configuration for enabled services
  enabledServices = filterAttrs (name: service: service.enable) services;
  
  mkTraefikConfig = services: {
    services = mapAttrs (name: service: {
      loadBalancer.servers = [{
        url = service.url;
      }];
    }) services;

    routers = mapAttrs (name: service: {
      entryPoints = ["websecure"];
      rule = "Host(`${service.subdomain}`)";
      service = name;
      middlewares = service.middlewares;
      tls.certResolver = "letsencrypt";
    }) services;
  };

in {
  imports = [
    ./flowise
    ./static
    ./meilisearch
  ];

  options.services.vlr.backend = {
    enable = mkEnableOption "Enable VLR backend services";

    # Define all service options here
    flowise = {
      enable = mkEnableOption "Enable Flowise AI service";
      # Add any flowise-specific options here
    };

    static = {
      enable = mkEnableOption "Enable static service";
      # Add any static-specific options here
    };

    meilisearch = {
      enable = mkEnableOption "Enable Meilisearch service";
      experimentalFeatures = {
        MEILI_EXPERIMENTAL_ENABLE_METRICS = true;
        MEILI_EXPERIMENTAL_VECTOR_STORE = true;
      };
      extraConfig = {
        MEILI_MAX_INDEXING_MEMORY = "2 GiB";
        MEILI_LOG_LEVEL = "INFO";
      };
    };
  };

  config = mkIf cfg.enable {
    # Set default values
    services.vlr.backend = {
      flowise.enable = mkDefault true;
      static.enable = mkDefault true;
      meilisearch.enable = mkDefault true;
    };

    # Generate Traefik configuration only for enabled services
    services.traefik.dynamicConfigOptions.http = mkTraefikConfig enabledServices;

    # Add systemd dependencies for enabled services
    systemd.services.traefik.after = 
      mapAttrsToList (name: service: "${name}.service") enabledServices;
  };
}
