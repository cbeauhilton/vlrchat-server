{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.backend.static;
  
  # Create a simple HTML file
  staticHtml = pkgs.writeText "index.html" ''
    <!DOCTYPE html>
    <html>
      <head>
        <title>VLR Static</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            max-width: 650px;
            margin: 40px auto;
            padding: 0 10px;
            color: #333;
          }
          .status {
            padding: 20px;
            border-radius: 8px;
            background: #f0f0f0;
            margin: 20px 0;
          }
        </style>
      </head>
      <body>
        <h1>VLR Static Test Page</h1>
        <div class="status">
          <h2>Authentication Status</h2>
          <p>If you can see this page, both Traefik routing and Authentik authentication are working correctly.</p>
        </div>
        <div class="status">
          <h2>Available Services</h2>
          <ul>
            <li><a href="https://auth.vlr.chat">Authentik Dashboard</a></li>
            <li><a href="https://flowise.vlr.chat">Flowise AI</a></li>
          </ul>
        </div>
      </body>
    </html>
  '';

in {
  config = mkIf cfg.enable {
    systemd.services.vlr-static = {
      description = "VLR Static Site";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python -m http.server 3001 --bind 0.0.0.0 --directory ${pkgs.runCommand "static-site" {} ''
          mkdir -p $out
          cp ${staticHtml} $out/index.html
        ''}";
        Restart = "always";
        RestartSec = "10";
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };
}
