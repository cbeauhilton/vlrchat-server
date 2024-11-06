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
    set -e
    echo "🔑 Generating secrets..."
    mkdir -p secrets
    if [ ! -f secrets/pg_pass ]; then
        # Generate a longer password (50 chars) for PostgreSQL
        nix-shell -p openssl --run "openssl rand -base64 50" > secrets/pg_pass
        echo "Generated new PostgreSQL password"
    else
        echo "Using existing PostgreSQL password"
    fi
    if [ ! -f secrets/authentik_secret ]; then
        # Generate a longer key (100 chars) for Django's SECRET_KEY
        nix-shell -p openssl --run "openssl rand -base64 100" > secrets/authentik_secret
        echo "Generated new Authentik secret key"
    else
        echo "Using existing Authentik secret key"
    fi
    # Ensure files aren't empty
    if [ ! -s secrets/pg_pass ] || [ ! -s secrets/authentik_secret ]; then
        echo "❌ Error: One or more secret files are empty"
        exit 1
    fi
    echo "✅ Secrets verified in ./secrets/"

# Deploy secrets to the host
deploy-secrets host=default_host:
    #!/usr/bin/env bash
    set -e
    echo "📦 Deploying secrets to {{host}}..."
    
    # Ensure secrets exist and aren't empty
    just generate-secrets
    
    # Create remote directory
    ssh -i {{ssh_key}} root@{{host}} "mkdir -p /var/lib/authentik/secrets"
    
    # Copy secrets
    scp -i {{ssh_key}} secrets/pg_pass secrets/authentik_secret root@{{host}}:/var/lib/authentik/secrets/
    
    # Set proper permissions and verify files
    ssh -i {{ssh_key}} root@{{host}} "\
        chown -R authentik:authentik /var/lib/authentik/secrets && \
        chmod -R 600 /var/lib/authentik/secrets/* && \
        if [ ! -s /var/lib/authentik/secrets/pg_pass ] || [ ! -s /var/lib/authentik/secrets/authentik_secret ]; then \
            echo '❌ Error: One or more deployed secret files are empty'; \
            exit 1; \
        fi"
    
    echo "✅ Secrets deployed and verified successfully"

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

# Generate self-signed certificate for Authentik
generate-cert host=default_host:
    #!/usr/bin/env bash
    echo "🔒 Generating self-signed certificate..."
    ssh -i {{ssh_key}} root@{{host}} "\
        mkdir -p /var/lib/authentik/certs && \
        nix-shell -p openssl --run \"openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /var/lib/authentik/certs/key.pem \
        -out /var/lib/authentik/certs/cert.pem \
        -subj '/CN=auth.vlr.chat'\" && \
        chown -R authentik:authentik /var/lib/authentik/certs && \
        chmod 600 /var/lib/authentik/certs/key.pem && \
        chmod 644 /var/lib/authentik/certs/cert.pem"
    echo "✅ Certificate generated successfully"

# Setup Authentik (full deployment)
setup-authentik host=default_host:
    #!/usr/bin/env bash
    set -e
    just generate-secrets
    just deploy-secrets {{host}}
    just generate-cert {{host}}
    just update {{host}}
    just check-status {{host}}
