#!/bin/bash
set -euo pipefail

echo "=== VMLogging Setup ==="

echo "[1/3] Setting vm.max_map_count for Elasticsearch..."
sudo sysctl -w vm.max_map_count=262144
grep -q "vm.max_map_count" /etc/sysctl.conf || \
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null

echo "[2/3] Copying certificates..."
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

echo "[3/3] Starting services..."
sudo docker compose up -d

echo ""
echo "VMLogging started!"
echo "  Kibana:        https://kibana.tp.local:8443"
echo "  Logstash:      port 5044 (Beats input)"
echo "  Traefik:       https://traefik-logging.tp.local:8443/dashboard/"
