{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend;
  
  # Helper function to create a standard service configuration
  mkServiceConfig = name: {
    enable ? false,
    port ? null,
    host ? null,
    middlewares ? ["authentik"],
  }: {
    inherit enable port host middlewares;
    url = "http://${host or "127.0.0.1"}:${toString port}";
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
  ];

  options.services.vlr.backend = {
    enable = mkEnableOption "Enable VLR backend services";
    
    flowise.enable = mkEnableOption "Enable Flowise AI service";
    static.enable = mkEnableOption "Enable static service";
    # Add new service options here
  };

  config = mkIf cfg.enable {
    # Set default values
    services.vlr.backend = {
      flowise.enable = mkDefault false;
      static.enable = mkDefault true;
    };

    # Generate Traefik configuration only for enabled services
    services.traefik.dynamicConfigOptions.http = mkTraefikConfig enabledServices;

    # Add systemd dependencies for enabled services
    systemd.services.traefik.after = 
      mapAttrsToList (name: service: "${name}.service") enabledServices;
  };
}
