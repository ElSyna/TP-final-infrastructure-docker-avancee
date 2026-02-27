# TP Final - Infrastructure Docker Avancée

Architecture distribuée de services conteneurisés sur 3 VMs avec reverse proxy Traefik, HTTPS auto-signé, SSO Keycloak, centralisation des logs ELK et monitoring Uptime Kuma.

## Architecture

```
┌─────────────────────────────┐  ┌────────────────────────────┐  ┌────────────────────────────┐
│       VM1 — VMApp           │  │     VM2 — VMLogging        │  │    VM3 — VMMonitoring      │
│                             │  │                            │  │                            │
│  Traefik (:443/:80)         │  │  Traefik (:8443/:8080)     │  │  Traefik (:9443/:9080)     │
│  ├─ WordPress               │  │  ├─ Elasticsearch 8.17     │  │  └─ Uptime Kuma            │
│  ├─ MariaDB 11              │  │  ├─ Logstash (:5044)       │  │                            │
│  ├─ phpMyAdmin (BasicAuth)  │  │  └─ Kibana                 │  │                            │
│  ├─ Keycloak 26 (OIDC)     │  │                            │  │                            │
│  └─ Filebeat ───────────────┼──►  Logstash                  │  │                            │
└─────────────────────────────┘  └────────────────────────────┘  └────────────────────────────┘

Réseau VMApp :
  frontend ── Traefik, WordPress, phpMyAdmin, Keycloak
  backend  ── MariaDB, WordPress, phpMyAdmin, Keycloak, Filebeat
```

## Prérequis

- 3 VMs Linux (Ubuntu 24.04) avec Docker et Docker Compose
- Accès réseau entre les VMs (Lima, VirtualBox, Proxmox…)

## Structure du dépôt

```
├── certs/                              # CA et certificat TLS partagé
│   ├── ca.crt
│   ├── server.crt
│   └── generate-certs.sh
├── VMApp/                              # VM1 — Application
│   ├── docker-compose.yml
│   ├── .env-example
│   ├── traefik/dynamic.yml
│   ├── filebeat/filebeat.yml
│   ├── init-db/01-create-keycloak-db.sql
│   └── setup.sh
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
└── README.md
```

## Déploiement

### 1. Générer les certificats TLS

```bash
cd certs && ./generate-certs.sh
```

### 2. Distribuer et truster la CA

Sur chaque VM Linux :
```bash
sudo cp ca.crt /usr/local/share/ca-certificates/tp-ca.crt
sudo update-ca-certificates
```

Sur macOS :
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```

### 3. Configurer /etc/hosts

Ajouter sur chaque machine (VMs + poste de travail) :
```
<IP_VM1> wordpress.tp.local pma.tp.local keycloak.tp.local traefik-app.tp.local
<IP_VM2> kibana.tp.local traefik-logging.tp.local
<IP_VM3> uptime.tp.local traefik-monitoring.tp.local
```

### 4. Déployer VMLogging (VM2) — en premier

```bash
cd VMLogging
cp .env-example .env   # configurer ELASTIC_PASSWORD et KIBANA_PASSWORD
./setup.sh
```

### 5. Déployer VMApp (VM1)

```bash
cd VMApp
cp .env-example .env   # configurer tous les mots de passe
./setup.sh
```

### 6. Déployer VMMonitoring (VM3)

```bash
cd VMMonitoring
./setup.sh
```

Puis créer un compte admin et ajouter les monitors dans Uptime Kuma.

## Services et accès

| Service | URL | Identifiants |
|---|---|---|
| WordPress | https://wordpress.tp.local | wpadmin (défini dans WP) |
| phpMyAdmin | https://pma.tp.local | BasicAuth (PMA_BASIC_AUTH dans .env) |
| Keycloak | https://keycloak.tp.local | KC_ADMIN_USER / KC_ADMIN_PASSWORD |
| Kibana | https://kibana.tp.local:8443 | elastic / ELASTIC_PASSWORD |
| Uptime Kuma | https://uptime.tp.local:9443 | Créé au premier accès |
| Traefik App | https://traefik-app.tp.local/dashboard/ | — |
| Traefik Logging | https://traefik-logging.tp.local:8443/dashboard/ | — |
| Traefik Monitoring | https://traefik-monitoring.tp.local:9443/dashboard/ | — |

## Stack technique

| Composant | Technologie |
|---|---|
| Reverse proxy | Traefik v3.6 |
| CMS | WordPress 6 + MariaDB 11 |
| Auth | Keycloak 26 (OpenID Connect) |
| Log shipping | Filebeat 8.17 |
| Log pipeline | Logstash 8.17 |
| Log storage | Elasticsearch 8.17 (single-node) |
| Log dashboard | Kibana 8.17 |
| Monitoring | Uptime Kuma |
| TLS | CA auto-signée, wildcard *.tp.local |

## Sécurité

- **HTTPS obligatoire** — redirection HTTP vers HTTPS sur les 3 VMs
- **Security headers** — X-Frame-Options, X-Content-Type-Options, HSTS, XSS-Protection, Referrer-Policy via middleware Traefik
- **Rate limiting** — 100 req/s avg, 200 burst sur tous les routers
- **Authentification** — phpMyAdmin (BasicAuth bcrypt), Kibana (xpack.security), WordPress SSO via Keycloak OIDC
- **Isolation réseau** — segmentation frontend/backend sur VMApp (Traefik n'accède pas à la DB, la DB n'est pas exposée)
- **Moindre privilège** — `no-new-privileges:true` sur tous les conteneurs, `cap_drop: ALL` sur Traefik, Filebeat, phpMyAdmin, Uptime Kuma
- **Resource limits** — `mem_limit` et `cpus` sur tous les conteneurs
- **Healthchecks** — tous les services avec `depends_on: condition: service_healthy`
- **Log rotation** — `json-file` driver, 10 Mo x 3 fichiers sur tous les conteneurs
- **Images versionnées** — aucun tag `latest`, toutes les images épinglées
- **Secrets** — tous les mots de passe dans `.env` (non commités), 32 bytes minimum
