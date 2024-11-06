#!/usr/bin/env bash
set -e

echo "🔑 Generating secrets..."
mkdir -p secrets

# Check if files exist and have content
if [ ! -s secrets/pg_pass ]; then
    echo "PostgreSQL password is empty or missing, generating new one..."
    openssl rand -base64 50 > secrets/pg_pass
    echo "Generated new PostgreSQL password"
else
    echo "Using existing PostgreSQL password"
fi

if [ ! -s secrets/authentik_secret ]; then
    echo "Authentik secret is empty or missing, generating new one..."
    openssl rand -base64 100 > secrets/authentik_secret
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
