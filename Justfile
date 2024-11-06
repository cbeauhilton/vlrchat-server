# Default host IP for deployment
default_host := "178.156.144.225"

# Deploy fresh NixOS installation to a remote host (default or specified)
deploy host=default_host:
    nix run github:numtide/nixos-anywhere -- \
        -i ~/.ssh/id_ed25519_hetzner_ \
        --flake .#nixos \
        root@{{host}}

# Deploy with full build logs
deploy-verbose host=default_host:
    nix run github:numtide/nixos-anywhere -- \
        -i ~/.ssh/id_ed25519_hetzner_ \
        -L \
        --flake .#nixos \
        root@{{host}}

# Update existing NixOS installation
update host=default_host:
    NIX_SSHOPTS="-i ~/.ssh/id_ed25519_hetzner_" \
    nixos-rebuild switch \
        --flake .#nixos \
        --target-host root@{{host}}

# Remove and add new host key - useful after a fresh deploy if you get warnings
trust-host host=default_host:
    ssh-keygen -R {{host}}
    ssh-keyscan -H {{host}} >> ~/.ssh/known_hosts

# Generate and set up authentik environment file on the host
setup-authentik host=default_host:
    chmod +x scripts/setup-authentik.sh
    ./scripts/setup-authentik.sh {{host}}

# Check container and service status
check-authentik host=default_host:
    #!/usr/bin/env bash
    echo "🔍 Checking container status..."
    ssh -i ~/.ssh/id_ed25519_hetzner_ root@{{host}} "docker ps -a | grep authentik"
    echo "📜 Container logs..."
    ssh -i ~/.ssh/id_ed25519_hetzner_ root@{{host}} "docker logs authentik 2>&1 | tail -n 50"
    echo "🔄 Service status..."
    ssh -i ~/.ssh/id_ed25519_hetzner_ root@{{host}} "systemctl status docker-authentik postgresql redis-authentik nginx"

# Force rebuild containers
rebuild-containers host=default_host:
    ssh -i ~/.ssh/id_ed25519_hetzner_ root@{{host}} "\
        systemctl stop docker-authentik; \
        docker rm -f authentik || true; \
        systemctl start docker-authentik"

# Default recipes at the top
default:
    @just --list
