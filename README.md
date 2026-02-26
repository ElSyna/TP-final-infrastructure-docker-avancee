# TP Final - Infrastructure Docker Avancée

Architecture distribuée de services conteneurisés sur 3 VMs avec Traefik, HTTPS auto-signé et centralisation des logs.

## Architecture

```
┌──────────────────────────┐  ┌───────────────────────────┐  ┌───────────────────────────┐
│     VM1 — VMApp          │  │    VM2 — VMLogging        │  │   VM3 — VMMonitoring      │
│                          │  │                           │  │                           │
│  Traefik (:443/:80)      │  │  Traefik (:8443/:8080)    │  │  Traefik (:9443/:9080)    │
│  WordPress               │  │  Elasticsearch 8.17       │  │  Uptime Kuma              │
│  MariaDB 11              │  │  Logstash (:5044)         │  │                           │
│  phpMyAdmin (BasicAuth)  │  │  Kibana                   │  │                           │
│  Keycloak 26 (OIDC)      │  │                           │  │                           │
│  Filebeat ───────────────┼──►  Logstash                 │  │                           │
└──────────────────────────┘  └───────────────────────────┘  └───────────────────────────┘
```

## Prérequis

- 3 VMs Linux (Ubuntu 24.04) avec Docker et Git
- Accès réseau entre les VMs (Lima, VirtualBox, Proxmox…)

## Structure du dépôt

```
├── certs/                          # CA et certificat TLS partagé
│   ├── ca.crt                      # Certificat CA public
│   ├── server.crt                  # Certificat serveur wildcard
│   └── generate-certs.sh           # Script de regénération
├── VMApp/                          # VM1 — Application
│   ├── docker-compose.yml
│   ├── .env-example
│   ├── traefik/dynamic.yml
│   ├── filebeat/filebeat.yml
│   ├── init-db/01-create-keycloak-db.sql
│   ├── setup.sh
│   └── configure-keycloak.sh
├── VMLogging/                      # VM2 — Logging (ELK)
│   ├── docker-compose.yml
│   ├── .env-example
│   ├── traefik/dynamic.yml
│   ├── logstash/config/logstash.yml
│   ├── logstash/pipeline/beats.conf
│   └── setup.sh
├── VMMonitoring/                   # VM3 — Monitoring
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
127.0.0.1 wordpress.tp.local pma.tp.local keycloak.tp.local traefik-app.tp.local
127.0.0.1 kibana.tp.local traefik-logging.tp.local
127.0.0.1 uptime.tp.local traefik-monitoring.tp.local
```

> Adaptez 127.0.0.1 par les IPs réelles si les VMs sont distantes.

### 4. Déployer VMLogging (VM2) — en premier

```bash
cd VMLogging
cp .env-example .env
./setup.sh
```

### 5. Déployer VMApp (VM1)

```bash
cd VMApp
cp .env-example .env   # éditer avec vos mots de passe
./setup.sh
./configure-keycloak.sh
```

### 6. Déployer VMMonitoring (VM3)

```bash
cd VMMonitoring
./setup.sh
```

Puis ajouter les monitors dans Uptime Kuma (https://uptime.tp.local:9443).

## Services et accès

| Service            | URL                                         | Identifiants                   |
|--------------------|---------------------------------------------|--------------------------------|
| WordPress          | https://wordpress.tp.local                  | wpadmin / WpAdmin2024!         |
| phpMyAdmin         | https://pma.tp.local                        | BasicAuth: admin / admin       |
| Keycloak Admin     | https://keycloak.tp.local                   | admin / KcAdm1n2024            |
| Keycloak Test User | via WordPress "Login with OpenID Connect"   | testuser / Test1234!           |
| Kibana             | https://kibana.tp.local:8443                | —                              |
| Uptime Kuma        | https://uptime.tp.local:9443                | Créé au premier accès          |
| Traefik App        | https://traefik-app.tp.local/dashboard/     | —                              |
| Traefik Logging    | https://traefik-logging.tp.local:8443/dashboard/ | —                         |
| Traefik Monitoring | https://traefik-monitoring.tp.local:9443/dashboard/ | —                    |

## Stack technique

| Composant      | Technologie                        |
|----------------|------------------------------------|
| Reverse proxy  | Traefik (latest)                   |
| CMS            | WordPress 6 + MariaDB 11          |
| Auth           | Keycloak 26 (OpenID Connect)       |
| Log shipping   | Filebeat 8.17                      |
| Log pipeline   | Logstash 8.17                      |
| Log storage    | Elasticsearch 8.17 (single-node)   |
| Log dashboard  | Kibana 8.17                        |
| Monitoring     | Uptime Kuma                        |
| TLS            | CA auto-signée, wildcard *.tp.local|

## Sécurité

- HTTPS obligatoire (redirection HTTP → HTTPS)
- phpMyAdmin protégé par Traefik BasicAuth (bcrypt)
- WordPress SSO via Keycloak OpenID Connect
- Secrets dans `.env` (non commités, voir `.env-example`)
- CA trustée sur toutes les VMs et le poste client
