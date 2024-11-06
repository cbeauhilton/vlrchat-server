{ config, ... }: {
  # Create required directories for authentik
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/data 0750 root root -"
    "d /var/lib/authentik/media 0750 root root -"
  ];

  virtualisation.oci-containers.containers.authentik = {
    image = "ghcr.io/goauthentik/server:latest";
    environmentFiles = [ "/run/secrets/authentik/authentik-env" ];
    
    ports = [
      "9000:9000"  # HTTP
      "9443:9443"  # HTTPS
    ];

    volumes = [
      "/var/lib/authentik/data:/data"
      "/var/lib/authentik/media:/media"
    ];
  };

  # Enable nginx and ACME for Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "beau@vlr.chat";
  };

  # Nginx reverse proxy configuration
  services.nginx.virtualHosts."auth.vlr.chat" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:9000";
      proxyWebsockets = true;
    };
  };
} 