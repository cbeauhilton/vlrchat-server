{ config, ... }: {
  services.authentik = {
    enable = true;
    environmentFile = "/run/secrets/authentik/authentik-env";
    settings = {
      disable_startup_analytics = true;
      avatars = "initials";
    };
    
    nginx = {
      enable = true;
      enableACME = true;
      host = "auth.vlr.chat";
    };
  };

  # Enable nginx and ACME for Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "beau@vlr.chat";
  };
} 