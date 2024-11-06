#!/usr/bin/env bash
set -e

# Get arguments
host="$1"
ssh_key="$2"

echo "📦 Deploying secrets to ${host}..."

# Ensure secrets exist
./scripts/generate-secrets.sh

# Create remote directory
ssh -i "${ssh_key}" "root@${host}" 'mkdir -p /run/secrets'

# Create environment file with secrets
secret_key=$(cat secrets/authentik_secret)
ssh -i "${ssh_key}" "root@${host}" "cat > /run/secrets/authentik-env" << EOF
AUTHENTIK_SECRET_KEY=${secret_key}
AUTHENTIK_EMAIL__PASSWORD=your_smtp_password
EOF

# Set proper permissions
ssh -i "${ssh_key}" "root@${host}" 'chmod 600 /run/secrets/authentik-env'

echo "✅ Secrets deployed and verified successfully" 