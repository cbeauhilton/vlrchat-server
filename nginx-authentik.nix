{ config, ... }: {
  services.nginx = {
    enable = true;
    
    # Recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."auth.vlr.chat" = {
      enableACME = false;  # We're using self-signed for now
      forceSSL = true;
      sslCertificate = "/var/lib/authentik/certs/cert.pem";
      sslCertificateKey = "/var/lib/authentik/certs/key.pem";
      
      locations."/" = {
        proxyPass = "http://localhost:9000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $host;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade_keepalive;
        '';
      };
    };
  };
}
