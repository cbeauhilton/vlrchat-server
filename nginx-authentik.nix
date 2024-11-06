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
      
      locations = {
        "/" = {
          proxyPass = "http://localhost:9000";
          proxyWebsockets = true;
        };
        "/ws" = {
          proxyPass = "http://localhost:9000";
          proxyWebsockets = true;
        };
      };
    };
  };
}
