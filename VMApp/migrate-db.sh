#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== VMApp Database Migration ==="
echo "This script migrates data from the old monolithic MariaDB to the new split instances."
echo ""

# Load old credentials
if [ ! -f .env.old ]; then
  echo "ERROR: .env.old not found. Copy your old .env to .env.old before running this script."
  exit 1
fi
source .env.old

OLD_CONTAINER="db"
DUMP_DIR="$(mktemp -d)"
trap "rm -rf $DUMP_DIR" EXIT

# Step 1: Dump databases from old container
echo "[1/6] Dumping WordPress database from old container..."
sudo docker exec "$OLD_CONTAINER" mariadb-dump \
  -u root -p"${MYSQL_ROOT_PASSWORD}" \
  --single-transaction --routines --triggers \
  wordpress > "$DUMP_DIR/wordpress.sql"
echo "  WordPress dump: $(wc -l < "$DUMP_DIR/wordpress.sql") lines"

echo "[2/6] Dumping Keycloak database from old container..."
sudo docker exec "$OLD_CONTAINER" mariadb-dump \
  -u root -p"${MYSQL_ROOT_PASSWORD}" \
  --single-transaction --routines --triggers \
  keycloak > "$DUMP_DIR/keycloak.sql"
echo "  Keycloak dump: $(wc -l < "$DUMP_DIR/keycloak.sql") lines"

# Step 2: Stop old stack
echo "[3/6] Stopping old monolithic stack..."
sudo docker compose -f docker-compose.yml.old down 2>/dev/null || true

# Step 3: Create proxy network and log dirs
echo "[4/6] Preparing new infrastructure..."
sudo docker network inspect proxy >/dev/null 2>&1 || sudo docker network create proxy
mkdir -p logs/{traefik,wordpress,keycloak,mariadb-wp,mariadb-kc}
chmod -R 750 logs/

# Step 4: Start new database containers only
echo "[5/6] Starting new MariaDB instances..."
sudo docker compose -f wordpress/docker-compose.yml up -d mariadb-wp
sudo docker compose -f keycloak/docker-compose.yml up -d mariadb-kc

echo "  Waiting for MariaDB-WP to be healthy..."
until sudo docker inspect --format='{{.State.Health.Status}}' mariadb-wp 2>/dev/null | grep -q "healthy"; do
  sleep 2
done

echo "  Waiting for MariaDB-KC to be healthy..."
until sudo docker inspect --format='{{.State.Health.Status}}' mariadb-kc 2>/dev/null | grep -q "healthy"; do
  sleep 2
done

# Step 5: Import dumps into new containers
echo "[6/6] Importing database dumps..."

# Load new WordPress credentials
source wordpress/.env
echo "  Importing WordPress database into mariadb-wp..."
sudo docker exec -i mariadb-wp mariadb \
  -u root -p"${MYSQL_ROOT_PASSWORD}" \
  wordpress < "$DUMP_DIR/wordpress.sql"

# Load new Keycloak credentials
source keycloak/.env
echo "  Importing Keycloak database into mariadb-kc..."
sudo docker exec -i mariadb-kc mariadb \
  -u root -p"${KC_MYSQL_ROOT_PASSWORD}" \
  keycloak < "$DUMP_DIR/keycloak.sql"

echo ""
echo "=== Migration complete! ==="
echo ""
echo "Next steps:"
echo "  1. Copy certificates: cp /opt/tp-certs/{ca.crt,server.crt,server.key} ./certs/"
echo "  2. Start all services: ./setup.sh"
echo "  3. Verify isolation:"
echo "     docker exec mariadb-wp ping -c1 8.8.8.8          # Should FAIL"
echo "     docker exec mariadb-wp ping -c1 mariadb-kc        # Should FAIL"
echo "     docker exec wordpress ping -c1 mariadb-wp          # Should SUCCEED"
echo "  4. Test services:"
echo "     curl -sk https://wordpress.tp.local"
echo "     curl -sk https://keycloak.tp.local"
echo "     curl -sk https://pma.tp.local"
