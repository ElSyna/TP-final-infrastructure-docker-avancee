#!/bin/bash
set -euo pipefail

echo "=== VMApp Setup ==="

echo "[1/3] Copying certificates..."
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

echo "[2/3] Creating log directories..."
mkdir -p logs/{traefik,wordpress,keycloak,db}
chmod -R 777 logs/

echo "[3/3] Starting services..."
sudo docker compose up -d

echo ""
echo "VMApp started! Run ./configure-keycloak.sh after services are healthy."
echo "  WordPress:   https://wordpress.tp.local"
echo "  phpMyAdmin:  https://pma.tp.local"
echo "  Keycloak:    https://keycloak.tp.local"
echo "  Traefik:     https://traefik-app.tp.local/dashboard/"
