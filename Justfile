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
    #!/usr/bin/env bash
    mkdir -p secrets
    if [ ! -f secrets/pg_pass ]; then
        nix-shell -p openssl --run "openssl rand -base64 32" > secrets/pg_pass
    fi
    if [ ! -f secrets/authentik_secret ]; then
        nix-shell -p openssl --run "openssl rand -base64 32" > secrets/authentik_secret
    fi
    echo "✅ Secrets generated in ./secrets/"

# Deploy secrets to the host
deploy-secrets host=default_host:
    #!/usr/bin/env bash
    set -e
    echo "📦 Deploying secrets to {{host}}..."
    
    # Ensure secrets exist
    just generate-secrets
    
    # Create remote directory and copy secrets
    ssh -i {{ssh_key}} root@{{host}} "mkdir -p /var/lib/authentik/secrets"
    scp -i {{ssh_key}} secrets/pg_pass secrets/authentik_secret root@{{host}}:/var/lib/authentik/secrets/
    
    # Set proper permissions
    ssh -i {{ssh_key}} root@{{host}} "\
        chown -R authentik:authentik /var/lib/authentik/secrets && \
        chmod -R 600 /var/lib/authentik/secrets/*"
    
    echo "✅ Secrets deployed successfully"

# Check container and service status
check-status host=default_host:
    #!/usr/bin/env bash
    echo "🔍 Checking container status..."
    ssh -i {{ssh_key}} root@{{host}} "docker ps -a | grep authentik"
    echo "📜 Container logs..."
    ssh -i {{ssh_key}} root@{{host}} "docker logs authentik-server 2>&1 | tail -n 50"
    echo "🔄 Service status..."
    ssh -i {{ssh_key}} root@{{host}} "systemctl status docker-authentik-server docker-authentik-worker docker-authentik-postgresql docker-authentik-redis nginx"

# Force rebuild containers
rebuild-containers host=default_host:
    ssh -i {{ssh_key}} root@{{host}} "\
        systemctl stop 'docker-authentik-*'; \
        docker rm -f authentik-server authentik-worker authentik-postgresql authentik-redis || true; \
        systemctl start 'docker-authentik-*'"

# Check secrets are in place
check-secrets host=default_host:
    #!/usr/bin/env bash
    echo "🔍 Checking secrets on {{host}}..."
    ssh -i {{ssh_key}} root@{{host}} "\
        ls -la /var/lib/authentik/secrets/ && \
        echo 'PostgreSQL password hash:' && \
        sha256sum /var/lib/authentik/secrets/pg_pass && \
        echo 'Authentik secret hash:' && \
        sha256sum /var/lib/authentik/secrets/authentik_secret"

# Setup Authentik (full deployment)
setup-authentik host=default_host:
    #!/usr/bin/env bash
    set -e
    just deploy-secrets {{host}}
    just update {{host}}
    just check-status {{host}}
