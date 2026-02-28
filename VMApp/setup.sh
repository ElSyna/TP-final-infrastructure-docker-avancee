#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== VMApp Setup ==="

# Copy certs
echo "[1/5] Copying certificates..."
mkdir -p certs
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

# Create log directories
echo "[2/5] Creating log directories..."
mkdir -p logs/{traefik,wordpress,keycloak,mariadb-wp,mariadb-kc}
chmod -R 750 logs/

# Create external network
echo "[3/5] Creating proxy network..."
sudo docker network inspect proxy >/dev/null 2>&1 || sudo docker network create proxy

# Start stacks in order
echo "[4/5] Starting Traefik..."
sudo docker compose -f traefik/docker-compose.yml up -d
echo "  Waiting for Traefik to be healthy..."
until sudo docker inspect --format='{{.State.Health.Status}}' traefik 2>/dev/null | grep -q "healthy"; do
  sleep 2
done
echo "  Traefik is healthy."

echo "[5/5] Starting application stacks..."
sudo docker compose -f wordpress/docker-compose.yml up -d
sudo docker compose -f keycloak/docker-compose.yml up -d

echo "  Waiting for databases to be healthy..."
until sudo docker inspect --format='{{.State.Health.Status}}' mariadb-wp 2>/dev/null | grep -q "healthy"; do
  sleep 2
done
echo "  MariaDB-WP is healthy."

until sudo docker inspect --format='{{.State.Health.Status}}' mariadb-kc 2>/dev/null | grep -q "healthy"; do
  sleep 2
done
echo "  MariaDB-KC is healthy."

echo "  Starting Filebeat..."
sudo docker compose -f filebeat/docker-compose.yml up -d

echo ""
echo "=== VMApp started! ==="
echo "Services:"
echo "  - WordPress:   https://wordpress.tp.local"
echo "  - phpMyAdmin:  https://pma.tp.local"
echo "  - Keycloak:    https://keycloak.tp.local"
echo "  - Traefik:     https://traefik-app.tp.local/dashboard/"
