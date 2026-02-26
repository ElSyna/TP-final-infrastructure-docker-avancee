#!/bin/bash
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$CERT_DIR"

echo "[1/4] Generating Root CA..."
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=TP-Docker-Infra/CN=TP Docker Root CA"

echo "[2/4] Creating SAN configuration..."
cat > san.cnf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.tp.local
DNS.2 = tp.local
DNS.3 = localhost
DNS.4 = host.lima.internal
IP.1 = 127.0.0.1
IP.2 = 192.168.5.2
IP.3 = 192.168.5.15
EOF

echo "[3/4] Generating server certificate..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/C=FR/ST=IDF/L=Paris/O=TP-Docker-Infra/CN=*.tp.local"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 3650 -sha256 -extfile san.cnf -extensions v3_req

echo "[4/4] Verifying..."
openssl verify -CAfile ca.crt server.crt
echo "Done! Certificates generated in $CERT_DIR"
