{ config, lib, ... }:
{
  services.vlr = {
    # Core infrastructure
    postgresql.enable = true;
    authentik.enable = true;
    traefik.enable = true;

    # Backend services
    backend = {
      enable = true;
      
      # Individual services
      static.enable = true;    # Landing page
      flowise.enable = true;  # AI service
      # serviceName.enable = true;  # Add new services here
    };
  };

  # Open required ports for services
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      80    # HTTP
      443   # HTTPS
      9000  # Authentik HTTP
      9443  # Authentik HTTPS
      # Add more service-specific ports here if needed
    ];
  };
}
