#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== VMApp Teardown ==="

echo "[1/4] Stopping Filebeat..."
sudo docker compose -f filebeat/docker-compose.yml down 2>/dev/null || true

echo "[2/4] Stopping Keycloak stack..."
sudo docker compose -f keycloak/docker-compose.yml down 2>/dev/null || true

echo "[3/4] Stopping WordPress stack..."
sudo docker compose -f wordpress/docker-compose.yml down 2>/dev/null || true

echo "[4/4] Stopping Traefik..."
sudo docker compose -f traefik/docker-compose.yml down 2>/dev/null || true

echo ""
echo "=== VMApp stopped ==="
echo "Note: The 'proxy' network was kept (other stacks may use it)."
echo "To remove it: sudo docker network rm proxy"
