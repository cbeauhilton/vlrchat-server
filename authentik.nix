{ config, ... }: {
  # Create required directories for authentik
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/data 0750 root root -"
    "d /var/lib/authentik/media 0750 root root -"
  ];

  # Configure PostgreSQL
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "authentik" ];
    ensureUsers = [{
      name = "authentik";
      ensureClauses = {
        login = true;
      };
    }];
  };

  # Add this after PostgreSQL configuration to grant privileges
  systemd.services.postgresql.postStart = lib.mkAfter ''
    $PSQL -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;"
  '';

  # Configure Redis for Authentik
  services.redis.servers."authentik" = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  virtualisation.oci-containers.containers.authentik = {
    image = "ghcr.io/goauthentik/server:latest";
    environmentFiles = [ "/run/secrets/authentik/authentik-env" ];
    
    # Add environment variables for PostgreSQL and Redis connection
    environment = {
      AUTHENTIK_POSTGRESQL__HOST = "/run/postgresql"; # Unix socket
      AUTHENTIK_POSTGRESQL__USER = "authentik";
      AUTHENTIK_POSTGRESQL__NAME = "authentik";
      AUTHENTIK_REDIS__HOST = "localhost";
      AUTHENTIK_REDIS__PORT = "6379";
    };
    
    ports = [
      "9000:9000"  # HTTP
      "9443:9443"  # HTTPS
    ];

    volumes = [
      "/var/lib/authentik/data:/data"
      "/var/lib/authentik/media:/media"
      "/run/postgresql:/run/postgresql" # Add PostgreSQL socket
    ];

    # Ensure PostgreSQL and Redis are ready before starting Authentik
    dependsOn = [ "postgresql" "redis-authentik" ];
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