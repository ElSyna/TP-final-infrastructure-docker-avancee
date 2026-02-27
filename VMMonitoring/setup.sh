#!/bin/bash
set -euo pipefail

echo "=== VMMonitoring Setup ==="

# Copy certs
echo "[1/2] Copying certificates..."
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

# Start services
echo "[2/2] Starting services..."
sudo docker compose up -d

echo ""
echo "VMMonitoring started! Services:"
echo "  - Uptime Kuma:  https://uptime.tp.local:9443"
echo "  - Traefik:      https://traefik.monitoring.tp.local:9443"
