#!/usr/bin/env bash
set -e

# Get arguments
host="$1"
ssh_key="$2"

echo "📦 Generating and deploying self-signed certificates..."

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout secrets/nginx-key.pem \
    -out secrets/nginx-cert.pem \
    -subj "/CN=auth.vlr.chat"

# Copy certificates to server
scp -i "${ssh_key}" secrets/nginx-cert.pem "root@${host}:/run/secrets/nginx-cert.pem"
scp -i "${ssh_key}" secrets/nginx-key.pem "root@${host}:/run/secrets/nginx-key.pem"

# Set proper permissions
ssh -i "${ssh_key}" "root@${host}" 'chmod 644 /run/secrets/nginx-cert.pem'
ssh -i "${ssh_key}" "root@${host}" 'chmod 600 /run/secrets/nginx-key.pem'

echo "✅ Self-signed certificates deployed successfully"
