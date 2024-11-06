#!/usr/bin/env bash

# Get arguments
SSH_KEY="$1"
HOST="$2"

ssh_cmd() {
    ssh -i "$SSH_KEY" "root@$HOST" "$1"
}

echo "═══════════════════════════════════════════════"
ssh_cmd "date '+%Y-%m-%d %H:%M:%S %Z'"
echo "═══════════════════════════════════════════════"
echo "🔍 Checking container status..."

# Get container names and show status
CONTAINERS=$(ssh_cmd "docker ps -a --format '{{.Names}}'")
ssh_cmd "docker ps -a"

echo
echo "───────────────────────────────────────────────"
echo "📜 Container logs (last 50 lines for each)..."
echo "Timestamp: $(ssh_cmd 'date "+%Y-%m-%d %H:%M:%S %Z"')"

# Show logs for each container
for container in $CONTAINERS; do
    echo
    echo "📄 Logs for ${container}:"
    echo "─────────────────────────────────���─────────────"
    ssh_cmd "docker logs ${container} 2>&1 | tail -n 50"
done

echo
echo "───────────────────────────────────────────────"
echo "🔄 Service status..."
echo "Timestamp: $(ssh_cmd 'date "+%Y-%m-%d %H:%M:%S %Z"')"

# Check status for each container's service
for container in $CONTAINERS; do
    ssh_cmd "systemctl status docker-${container}"
done
ssh_cmd "systemctl status nginx"
echo "═══════════════════════════════════════════════"
