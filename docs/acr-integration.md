# Azure Container Registry (ACR) Integration

Diese Dokumentation beschreibt, wie die Azure Container Registry (ACR) mit dem Nomad Cluster integriert ist.

## Überblick

Die Integration ermöglicht es Nomad Client Nodes, Container-Images aus der privaten Azure Container Registry zu pullen, ohne explizite Credentials zu benötigen.

## Komponenten

1. **Azure Container Registry (ACR)**
   - Private Registry für Container-Images
   - Erstellt im `services`-Modul

2. **Managed Identity für VMSS**
   - System-assigned Identity für Nomad Client VMSS
   - RBAC-Rolle "AcrPull" für Zugriff auf ACR

3. **Docker-Treiber in Nomad**
   - Installiert via Cloud-Init auf Client Nodes
   - Konfiguriert für ACR-Authentifizierung

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

### Nomad Client Konfiguration

Die Nomad Client Konfiguration enthält:

```hcl
plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
    auth {
      helper = "acr-env"
    }
  }
}
```

## Verwendung in Nomad Jobs

Um Container-Images aus der ACR zu verwenden, konfiguriere den Docker-Treiber wie folgt:

```hcl
task "example" {
  driver = "docker"
  
  config {
    image = "${ACR_NAME}.azurecr.io/my-image:latest"
    auth {
      helper = "acr-env"
    }
  }
}
```

Siehe `examples/acr-job.nomad` für ein vollständiges Beispiel.

## Troubleshooting

Bei Problemen mit der ACR-Integration:

1. Prüfe, ob die RBAC-Rolle korrekt zugewiesen ist
2. Überprüfe die Managed Identity der VMSS
3. Prüfe die Docker-Logs auf den Client Nodes
4. Verifiziere die Nomad Client Konfiguration
