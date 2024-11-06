{ config, ... }: {
  services.nginx = {
    enable = true;
    
    # Add these settings
    appendConfig = ''
      worker_processes auto;
      worker_rlimit_nofile 65535;
    '';
    
    # Existing settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Add this to handle websocket upgrades properly
    upstreamBlocks = ''
      upstream authentik {
        server localhost:9000;
      }
    '';

    virtualHosts."auth.vlr.chat" = {
      enableACME = false;
      forceSSL = true;
      sslCertificate = "/var/lib/authentik/certs/cert.pem";
      sslCertificateKey = "/var/lib/authentik/certs/key.pem";
      
      locations."/" = {
        proxyPass = "http://authentik";  # Updated to use upstream
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

  # Add this to ensure proper connection upgrade handling
  services.nginx.appendHttpConfig = ''
    map $http_upgrade $connection_upgrade_keepalive {
      default upgrade;
      '''      close;
    }
  '';
}
