#!/usr/bin/env bash
set -e

# Get arguments
host="$1"
ssh_key="$2"

echo "📦 Generating and deploying self-signed certificates..."

# Create secrets directory if it doesn't exist
mkdir -p secrets

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout secrets/nginx-key.pem \
    -out secrets/nginx-cert.pem \
    -subj "/CN=auth.vlr.chat"

# Create remote directory
ssh -i "${ssh_key}" "root@${host}" 'mkdir -p /var/lib/nginx/certs'

# Copy certificates to server
scp -i "${ssh_key}" secrets/nginx-cert.pem "root@${host}:/var/lib/nginx/certs/cert.pem"
scp -i "${ssh_key}" secrets/nginx-key.pem "root@${host}:/var/lib/nginx/certs/key.pem"

# Set proper permissions
ssh -i "${ssh_key}" "root@${host}" 'chown -R nginx:nginx /var/lib/nginx/certs'
ssh -i "${ssh_key}" "root@${host}" 'chmod 644 /var/lib/nginx/certs/cert.pem'
ssh -i "${ssh_key}" "root@${host}" 'chmod 600 /var/lib/nginx/certs/key.pem'

echo "✅ Self-signed certificates deployed successfully"
