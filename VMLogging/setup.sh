#!/bin/bash
set -euo pipefail

echo "=== VMLogging Setup ==="

# Elasticsearch requires this
echo "[1/3] Setting vm.max_map_count..."
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null

# Copy certs
echo "[2/3] Copying certificates..."
cp /opt/tp-certs/ca.crt ./certs/
cp /opt/tp-certs/server.crt ./certs/
cp /opt/tp-certs/server.key ./certs/

# Start services
echo "[3/3] Starting services..."
sudo docker compose up -d

echo ""
echo "VMLogging started! Services:"
echo "  - Kibana:        https://kibana.tp.local:8443"
echo "  - Logstash:      port 5044 (Beats input)"
echo "  - Elasticsearch: port 9200 (internal)"
echo "  - Traefik:       https://traefik.logging.tp.local:8443"
