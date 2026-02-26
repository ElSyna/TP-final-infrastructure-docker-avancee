#\!/bin/bash
set -euo pipefail
echo "=== Keycloak Post-Deploy Configuration ==="
echo "Waiting for Keycloak to be ready..."
until sudo docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master \
  --user ${KC_ADMIN_USER:-admin} --password ${KC_ADMIN_PASSWORD:-admin} 2>/dev/null; do
  sleep 5
done

KC="sudo docker exec keycloak /opt/keycloak/bin/kcadm.sh"

echo "[1/4] Creating WordPress realm..."
$KC create realms -s realm=wordpress -s enabled=true

echo "[2/4] Creating OIDC client..."
$KC create clients -r wordpress \
  -s clientId=wordpress-oidc \
  -s name="WordPress OIDC" \
  -s enabled=true \
  -s publicClient=false \
  -s clientAuthenticatorType=client-secret \
  -s secret=wp-oidc-secret-2024 \
  -s "redirectUris=[\"https://wordpress.tp.local/*\"]" \
  -s "webOrigins=[\"https://wordpress.tp.local\"]" \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s protocol=openid-connect

echo "[3/4] Creating test users..."
$KC create users -r wordpress -s username=testuser -s enabled=true \
  -s email=testuser@tp.local -s firstName=Test -s lastName=User -s emailVerified=true
$KC set-password -r wordpress --username testuser --new-password Test1234\!

$KC create users -r wordpress -s username=admin-wp -s enabled=true \
  -s email=admin@tp.local -s firstName=Admin -s lastName=WordPress -s emailVerified=true
$KC set-password -r wordpress --username admin-wp --new-password Admin1234\!

echo "[4/4] Configuring WordPress OIDC plugin..."
sudo docker exec wordpress wp core install \
  --url="https://wordpress.tp.local" \
  --title="TP Docker Infrastructure" \
  --admin_user=wpadmin \
  --admin_password=WpAdmin2024\! \
  --admin_email=admin@tp.local \
  --skip-email --allow-root 2>/dev/null || true

sudo docker exec wordpress bash -c "
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
  chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"

sudo docker exec wordpress wp plugin install daggerhart-openid-connect-generic --activate --allow-root 2>/dev/null || true

sudo docker exec wordpress wp option update openid_connect_generic_settings --format=json --allow-root '{"login_type":"button","client_id":"wordpress-oidc","client_secret":"wp-oidc-secret-2024","scope":"openid email profile","endpoint_login":"https://keycloak.tp.local/realms/wordpress/protocol/openid-connect/auth","endpoint_userinfo":"https://keycloak.tp.local/realms/wordpress/protocol/openid-connect/userinfo","endpoint_token":"https://keycloak.tp.local/realms/wordpress/protocol/openid-connect/token","endpoint_end_session":"https://keycloak.tp.local/realms/wordpress/protocol/openid-connect/logout","identity_key":"preferred_username","nickname_key":"preferred_username","email_format":"{email}","displayname_format":"{given_name} {family_name}","identify_with_username":true,"link_existing_users":true,"create_if_does_not_exist":true,"redirect_user_back":true,"redirect_on_logout":true,"enable_logging":false}'

echo "Configuration complete\!"
