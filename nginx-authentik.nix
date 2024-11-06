{ config, pkgs, ... }: {
  services.nginx = {
    enable = true;
    
    # Basic recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Simple virtual host configuration
    virtualHosts."auth.vlr.chat" = {
      enableACME = false;
      forceSSL = false;
      
      # Serve a static HTML page
      root = "/var/lib/authentik/static";
      locations."/" = {
        index = "index.html";
      };
    };
  };

  # Create the static directory and HTML file
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/static 0755 authentik authentik -"
    "f /var/lib/authentik/static/index.html 0644 authentik authentik - <!DOCTYPE html><html><head><title>Auth Test Page</title></head><body><h1>Auth Test Page</h1><p>If you can see this, nginx is working correctly!</p></body></html>"
  ];
}
