{ config, ... }: {
  services.authentik = {
    enable = true;
    # The environmentFile will need to be created on the host
    environmentFile = "/run/secrets/authentik/authentik-env";
    settings = {
    #   email = { # not using email, this section left for potential future reference
    #     host = "smtp.gmail.com";  # Update this with your SMTP server
    #     port = 587;
    #     username = "your-email@vlr.chat";  # Update this
    #     use_tls = true;
    #     use_ssl = false;
    #     from = "authentik@vlr.chat";  # Update this
    #   };
      disable_startup_analytics = true;
      avatars = "initials";
    };
    
    # Configure nginx with Let's Encrypt
    nginx = {
      enable = true;
      enableACME = true;
      host = "auth.vlr.chat";
    };
  };

  # Enable nginx and ACME for Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "your-email@vlr.chat";  # Update this
  };
} 