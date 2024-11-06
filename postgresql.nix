{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.vlr.postgresql;
in {
  options.services.vlr.postgresql = {
    enable = mkEnableOption "Enable postgresql";
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
    };
  };
}
