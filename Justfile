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
    
    # Check if files exist and have content
    if [ ! -s secrets/pg_pass ]; then
        echo "PostgreSQL password is empty or missing, generating new one..."
        nix-shell -p openssl --run "openssl rand -base64 50" > secrets/pg_pass
        echo "Generated new PostgreSQL password"
    else
        echo "Using existing PostgreSQL password"
    fi
    
    if [ ! -s secrets/authentik_secret ]; then
        echo "Authentik secret is empty or missing, generating new one..."
        nix-shell -p openssl --run "openssl rand -base64 100" > secrets/authentik_secret
        echo "Generated new Authentik secret key"
    else
        echo "Using existing Authentik secret key"
    fi
    
    # Final verification
    if [ ! -s secrets/pg_pass ] || [ ! -s secrets/authentik_secret ]; then
        echo "❌ Error: Failed to generate secrets"
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
    ssh -i {{ssh_key}} root@{{host}} "mkdir -p /run/secrets"
    
    # Create environment file with secrets
    ssh -i {{ssh_key}} root@{{host}} "cat > /run/secrets/authentik-env << EOF
AUTHENTIK_SECRET_KEY=\$(cat secrets/authentik_secret)
AUTHENTIK_EMAIL__PASSWORD=your_smtp_password
EOF"
    
    # Set proper permissions
    ssh -i {{ssh_key}} root@{{host}} "chmod 600 /run/secrets/authentik-env"
    
    echo "✅ Secrets deployed and verified successfully"

# Check container and service status
check-status host=default_host:
    ssh -i {{ssh_key}} root@{{host}} "systemctl status authentik-*"

# Setup Authentik (full deployment)
setup-authentik host=default_host:
    #!/usr/bin/env bash
    set -e
    just generate-secrets
    just deploy-secrets {{host}}
    just update {{host}}
    just check-status {{host}}
