#!/bin/bash
set -euo pipefail

echo "=== VMMonitoring Setup ==="

echo "[1/2] Copying certificates..."
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

echo "[2/2] Starting services..."
sudo docker compose up -d

echo ""
echo "VMMonitoring started!"
echo "  Uptime Kuma:  https://uptime.tp.local:9443"
echo "  Traefik:      https://traefik-monitoring.tp.local:9443/dashboard/"
echo ""
echo "Add these monitors in Uptime Kuma:"
echo "  - https://wordpress.tp.local          (WordPress)"
echo "  - https://pma.tp.local                (phpMyAdmin)"
echo "  - https://keycloak.tp.local           (Keycloak)"
echo "  - https://kibana.tp.local:8443        (Kibana)"
