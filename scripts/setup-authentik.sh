#!/usr/bin/env bash
set -euo pipefail

# Check if host argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <host>"
    exit 1
fi

HOST="$1"

# Generate a new secret key
SECRET_KEY=$(openssl rand -base64 32)

# Create the directory and environment file on the remote host
ssh -i ~/.ssh/id_ed25519_hetzner_ root@"${HOST}" "mkdir -p /run/secrets/authentik && \
    cat > /run/secrets/authentik/authentik-env << EOF
AUTHENTIK_SECRET_KEY=${SECRET_KEY}
AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_LOG_LEVEL=info
EOF
    chmod 600 /run/secrets/authentik/authentik-env"

echo "✅ Authentik environment file created at /run/secrets/authentik/authentik-env"
echo "🔑 Secret key has been set" 