# TP Final - Infrastructure Docker Avancée

Architecture distribuée de services conteneurisés sur 3 VMs avec reverse proxy Traefik, HTTPS auto-signé, SSO Keycloak, centralisation des logs ELK et monitoring Uptime Kuma.

## Architecture

```
┌─────────────────────────────────┐  ┌────────────────────────────┐  ┌────────────────────────────┐
│        VM1 — VMApp              │  │     VM2 — VMLogging        │  │    VM3 — VMMonitoring      │
│                                 │  │                            │  │                            │
│  Traefik (:443/:80)            │  │  Traefik (:8443/:8080)     │  │  Traefik (:9443/:9080)     │
│  ├─ WordPress                  │  │  ├─ Elasticsearch 8.17     │  │  └─ Uptime Kuma            │
│  ├─ MariaDB-WP (isolé)        │  │  ├─ Logstash (:5044)       │  │                            │
│  ├─ phpMyAdmin (BasicAuth)     │  │  └─ Kibana                 │  │                            │
│  ├─ Keycloak 26 (OIDC)        │  │                            │  │                            │
│  ├─ MariaDB-KC (isolé)        │  │                            │  │                            │
│  └─ Filebeat ──────────────────┼──►  Logstash                  │  │                            │
└─────────────────────────────────┘  └────────────────────────────┘  └────────────────────────────┘
```

### Réseau VMApp (4 stacks isolés)

```
                    proxy (external)
          Traefik, WordPress, phpMyAdmin, Keycloak
                   /                \
        wp-internal                  kc-internal        (internal: true)
   WordPress, phpMyAdmin,        Keycloak, MariaDB-KC
   MariaDB-WP
```

- `mariadb-wp` : uniquement sur `wp-internal` — pas d'internet, pas d'accès au stack Keycloak
- `mariadb-kc` : uniquement sur `kc-internal` — pas d'internet, pas d'accès au stack WordPress

## Structure du dépôt

```
├── certs/                              # CA et certificat TLS partagé
│   ├── ca.crt
│   ├── server.crt
│   └── generate-certs.sh
├── VMApp/                              # VM1 — Application (4 stacks)
│   ├── traefik/
│   │   ├── docker-compose.yml          # Traefik (réseau proxy)
│   │   └── dynamic.yml                 # TLS + middlewares sécurité
│   ├── wordpress/
│   │   ├── docker-compose.yml          # WordPress + phpMyAdmin + MariaDB-WP
│   │   └── .env-example
│   ├── keycloak/
│   │   ├── docker-compose.yml          # Keycloak + MariaDB-KC
│   │   └── .env-example
│   ├── filebeat/
│   │   ├── docker-compose.yml          # Filebeat
│   │   └── filebeat.yml
│   ├── setup.sh                        # Démarrage orchestré
│   ├── teardown.sh                     # Arrêt propre
│   └── migrate-db.sh                   # Migration depuis ancien stack
├── VMLogging/                          # VM2 — Logging (ELK)
│   ├── docker-compose.yml
│   ├── .env-example
│   ├── traefik/dynamic.yml
│   ├── logstash/config/logstash.yml
│   ├── logstash/pipeline/beats.conf
│   └── setup.sh
├── VMMonitoring/                       # VM3 — Monitoring
│   ├── docker-compose.yml
│   ├── .env-example
│   ├── traefik/dynamic.yml
│   └── setup.sh
├── CHOIX-TECHNIQUES.pdf                # Rapport des choix techniques
└── README.md
```

## Prérequis

- 3 VMs Linux (Ubuntu 24.04) avec Docker et Docker Compose
- Accès réseau entre les VMs

## Déploiement

### 1. Générer les certificats TLS

```bash
cd certs
./generate-certs.sh
```

Cela génère une CA racine et un certificat wildcard `*.tp.local`.

### 2. Distribuer et truster la CA

Copier `certs/ca.crt`, `certs/server.crt` et `certs/server.key` dans `/opt/tp-certs/` sur chaque VM, puis :

```bash
sudo cp /opt/tp-certs/ca.crt /usr/local/share/ca-certificates/tp-ca.crt
sudo update-ca-certificates
```

Sur macOS (poste de travail) :
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```

### 3. Configurer /etc/hosts

Sur chaque machine (VMs + poste de travail) :
```
<IP_VM1>  wordpress.tp.local pma.tp.local keycloak.tp.local traefik-app.tp.local
<IP_VM2>  kibana.tp.local traefik-logging.tp.local logstash.tp.local
<IP_VM3>  uptime.tp.local traefik-monitoring.tp.local
```

### 4. Déployer VMLogging (VM2) — en premier

L'infra de logs doit exister avant VMApp (Filebeat a besoin de Logstash).

```bash
cd VMLogging
cp .env-example .env
# Éditer .env : définir ELASTIC_PASSWORD et KIBANA_PASSWORD
nano .env
./setup.sh
```

Vérifier :
```bash
curl -sk https://kibana.tp.local:8443          # Kibana
curl -sk https://traefik-logging.tp.local:8443/dashboard/  # Traefik
```

### 5. Déployer VMApp (VM1)

```bash
cd VMApp

# Configurer les credentials de chaque stack
cp wordpress/.env-example wordpress/.env
nano wordpress/.env

cp keycloak/.env-example keycloak/.env
nano keycloak/.env

# Lancer (crée le réseau proxy, démarre dans l'ordre)
./setup.sh
```

Le script `setup.sh` :
1. Copie les certificats depuis `/opt/tp-certs/`
2. Crée les répertoires de logs
3. Crée le réseau Docker `proxy`
4. Démarre Traefik → attend healthy
5. Démarre WordPress + Keycloak → attend healthy
6. Démarre Filebeat

Vérifier :
```bash
curl -sk https://wordpress.tp.local             # WordPress
curl -sk https://keycloak.tp.local              # Keycloak
curl -sk https://pma.tp.local                   # phpMyAdmin (401 = BasicAuth OK)
curl -sk https://traefik-app.tp.local/dashboard/ # Traefik
```

Pour arrêter :
```bash
./teardown.sh
```

### 6. Déployer VMMonitoring (VM3)

```bash
cd VMMonitoring
cp .env-example .env
./setup.sh
```

Puis créer un compte admin dans Uptime Kuma (`https://uptime.tp.local:9443`) et ajouter les monitors pour tous les services.

Vérifier :
```bash
curl -sk https://uptime.tp.local:9443           # Uptime Kuma
curl -sk https://traefik-monitoring.tp.local:9443/dashboard/
```

### 7. Configurer Keycloak pour WordPress

1. Accéder à `https://keycloak.tp.local` avec les credentials admin (définis dans `keycloak/.env`)
2. Créer un realm `wordpress`
3. Créer un client `wordpress-oidc` (type OpenID Connect, redirect URI : `https://wordpress.tp.local/*`)
4. Créer des utilisateurs de test
5. Dans WordPress, installer le plugin "OpenID Connect Generic" et le configurer avec les endpoints du realm

## Services et accès

| Service | URL | Identifiants |
|---------|-----|-------------|
| WordPress | https://wordpress.tp.local | admin WP ou SSO via Keycloak |
| phpMyAdmin | https://pma.tp.local | BasicAuth (PMA_BASIC_AUTH) + login MariaDB |
| Keycloak | https://keycloak.tp.local | KC_ADMIN_USER / KC_ADMIN_PASSWORD |
| Kibana | https://kibana.tp.local:8443 | elastic / ELASTIC_PASSWORD |
| Uptime Kuma | https://uptime.tp.local:9443 | Créé au premier accès |
| Traefik App | https://traefik-app.tp.local/dashboard/ | — |
| Traefik Logging | https://traefik-logging.tp.local:8443/dashboard/ | — |
| Traefik Monitoring | https://traefik-monitoring.tp.local:9443/dashboard/ | — |

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Reverse proxy | Traefik v3.6 |
| CMS | WordPress 6 + MariaDB 11 |
| Auth | Keycloak 26 (OpenID Connect) |
| Log shipping | Filebeat 8.17 |
| Log pipeline | Logstash 8.17 |
| Log storage | Elasticsearch 8.17 (single-node) |
| Log dashboard | Kibana 8.17 |
| Monitoring | Uptime Kuma |
| TLS | CA auto-signée, wildcard *.tp.local |
