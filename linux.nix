{
  username,
  hostname,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./modules/postgresql
    ./modules/authentik
    ./modules/traefik
    ./modules/backend-services
    ./select-services.nix
  ];

  time.timeZone = "America/Chicago";

  systemd.tmpfiles.rules = [
    "d /home/${username}/.config 0755 ${username} users"
    "d /home/${username}/.config/lvim 0755 ${username} users"
  ];

  networking.hostName = "${hostname}";

  programs.zsh.enable = true;
  environment.pathsToLink = ["/share/zsh"];
  environment.shells = [pkgs.zsh];

  environment.enableAllTerminfo = true;

  security.sudo.wheelNeedsPassword = false;

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ./id_ed25519_hetzner_.pub)
    ];
  };

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  system.stateVersion = "22.05";

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune.enable = true;
    };
    oci-containers.backend = "docker";
  };

  nix = {
    settings = {
      trusted-users = [username];
      accept-flake-config = true;
      auto-optimise-store = true;
    };

    registry.nixpkgs.flake = inputs.nixpkgs;

    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
      "nixos-config=/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

    package = pkgs.nixFlakes;
    extraOptions = ''experimental-features = nix-command flakes'';

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
