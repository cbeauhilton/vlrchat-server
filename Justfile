# Default host IP for deployment
default_host := "178.156.144.225"
ssh_key := "~/.ssh/id_ed25519_hetzner_"

# Default recipes at the top
default:
    @just --list

# Deploy fresh NixOS installation to a remote host
deploy host=default_host:
    nix run github:numtide/nixos-anywhere -- \
        -i {{ssh_key}} \
        --flake .#nixos \
        root@{{host}}

# Deploy with full build logs
deploy-verbose host=default_host:
    nix run github:numtide/nixos-anywhere -- \
        -i {{ssh_key}} \
        -L \
        --flake .#nixos \
        root@{{host}}

# Update existing NixOS installation
update host=default_host:
    NIX_SSHOPTS="-i {{ssh_key}}" \
    nixos-rebuild switch \
        --flake .#nixos \
        --target-host root@{{host}}

# Remove and add new host key - useful after a fresh deploy
trust-host host=default_host:
    ssh-keygen -R {{host}}
    ssh-keyscan -H {{host}} >> ~/.ssh/known_hosts

# Generate secrets for Authentik
generate-secrets:
    ./scripts/generate-secrets.sh

# Deploy secrets to the host
deploy-secrets host=default_host:
    ./scripts/deploy-secrets.sh {{host}} {{ssh_key}}

# Check container and service status
check-status host=default_host:
    ssh -i {{ssh_key}} root@{{host}} 'systemctl status authentik-*'

# Setup Authentik (full deployment)
setup-authentik host=default_host:
    just generate-secrets
    just deploy-secrets {{host}}
    just update {{host}}
    just check-status {{host}}
