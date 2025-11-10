# Azure Container Registry (ACR) Integration

Diese Dokumentation beschreibt, wie die Azure Container Registry (ACR) mit dem Nomad Cluster integriert ist.

## Überblick

Die Integration ermöglicht es Nomad Client Nodes, Container-Images aus der privaten Azure Container Registry zu pullen.

## Authentifizierungsmethoden

### Methode 1: Admin-Credentials (aktuell aktiv)

Diese Methode ist für Demo- und Entwicklungsumgebungen geeignet.

**Vorteile:**
- Einfache Einrichtung
- Keine komplexe Konfiguration erforderlich
- Funktioniert sofort nach dem Deployment

**Nachteile:**
- Weniger sicher als Managed Identity
- Nicht empfohlen für Produktionsumgebungen

**Komponenten:**
1. **Azure Container Registry (ACR)**
   - Private Registry für Container-Images
   - Admin-Credentials aktiviert (`admin_enabled = true`)
   - Erstellt im `services`-Modul

2. **Docker Login auf Client Nodes**
   - Automatisches `docker login` beim Hochfahren
   - Verwendet ACR Admin-Credentials
   - Konfiguriert via Cloud-Init

### Methode 2: Managed Identity (für Produktion)

Diese Methode ist für Produktionsumgebungen empfohlen, aber komplexer einzurichten.

**Vorteile:**
- Sicherer als Admin-Credentials
- Keine Credentials im Code oder in der Konfiguration
- Automatische Rotation der Tokens

**Nachteile:**
- Komplexere Einrichtung
- Erfordert zusätzliche Azure-Konfiguration

**Komponenten:**
1. **Managed Identity für VMSS**
   - System-assigned Identity für Nomad Client VMSS
   - RBAC-Rolle "AcrPull" für Zugriff auf ACR

2. **Docker-Credential-Helper**
   - Verwendet Azure CLI für Authentifizierung
   - Automatische Token-Verwaltung

## Konfiguration

### Terraform

Die ACR-Integration wird in folgenden Dateien konfiguriert:

- `terraform/modules/compute/main.tf`:
  - Managed Identity für VMSS
  - RBAC-Rolle für ACR Pull
  - Docker Installation via Cloud-Init

- `terraform/modules/compute/variables.tf`:
  - ACR ID Variable

- `terraform/main.tf`:
  - ACR ID vom Services-Modul zum Compute-Modul übergeben

### Nomad client configuration (Admin credentials)

With the current demo setup, Docker authentication is configured at the client (host) level and consumed by Nomad's Docker plugin via an auth config file. Minimal plugin configuration:

```hcl
plugin "docker" {
  config {
    allow_privileged = true
    volumes { enabled = true }

    # Use host-level Docker auth (created by cloud-init)
    auth {
      config = "/etc/docker/config.json"
    }
  }
}
```

Notes:
- `/etc/docker/config.json` must be readable by Nomad: directory `/etc/docker` → 755, file `/etc/docker/config.json` → 644, owner `root:root`.
- The file is created by cloud-init on each client. Template path: `terraform/modules/compute/templates/nomad-client-cloud-init.yaml.tftpl`.
- For production, prefer Managed Identity + credential helper instead of admin credentials.

## Verwendung in Nomad Jobs

Um Container-Images aus der ACR zu verwenden, konfiguriere den Docker-Treiber wie folgt:

```hcl
task "example" {
  driver = "docker"
  
  config {
    image = "${ACR_NAME}.azurecr.io/my-image:latest"
    ports = ["http"]
  }
}
```

**Wichtig:** Mit der Admin-Credentials-Methode ist kein `auth`-Block im Job erforderlich, da die Authentifizierung bereits auf Host-Ebene erfolgt ist.

## Troubleshooting

Bei Problemen mit der ACR-Integration:

1. Prüfe, ob die RBAC-Rolle korrekt zugewiesen ist
2. Überprüfe die Managed Identity der VMSS
3. Prüfe die Docker-Logs auf den Client Nodes
4. Verifiziere die Nomad Client Konfiguration
