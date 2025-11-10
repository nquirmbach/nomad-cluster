# Nomad Cluster in Azure

Dieses Projekt implementiert einen hochverfügbaren HashiCorp Nomad Cluster in Azure mittels Terraform und Ansible. Der Cluster wird über GitHub Actions automatisiert bereitgestellt und kann für die Orchestrierung verschiedener Workloads verwendet werden.

## Überblick

### Was ist Nomad?

[HashiCorp Nomad](https://www.nomadproject.io/) ist ein flexibler Workload-Orchestrator, der die Bereitstellung und Verwaltung von Containern und nicht-containerisierten Anwendungen vereinfacht. Im Vergleich zu Kubernetes bietet Nomad einen schlankeren Ansatz mit geringerer Komplexität.

### Hauptfunktionen

- **Hochverfügbarer Cluster**: 3-Server-Setup für Consensus und Ausfallsicherheit
- **Auto-Scaling**: Automatische Skalierung der Client-Nodes basierend auf Auslastung
- **Infrastructure as Code**: Vollständig automatisierte Bereitstellung mit Terraform
- **CI/CD-Integration**: GitHub Actions Workflows für Infrastruktur und Anwendungen
- **Container Registry**: Azure Container Registry (ACR) Integration mit Managed Identity
- **Secrets Management**: Azure Key Vault für sichere Speicherung von Secrets

### Technologie-Stack

- **Infrastruktur**: Azure (VMSS, Load Balancer, Key Vault, ACR)
- **IaC**: Terraform für Azure-Ressourcen
- **Konfiguration**: Ansible für Server, Cloud-Init für Clients
- **CI/CD**: GitHub Actions mit OIDC-Authentifizierung
- **Orchestrierung**: HashiCorp Nomad + Consul

## Projektstruktur

```
nomad-cluster/
├── .github/workflows/       # GitHub Actions Workflows
├── ansible/                 # Ansible für Server-Konfiguration
├── terraform/               # Terraform IaC für Azure
├── jobs/                    # Nomad Job-Definitionen
└── docs/                    # Detaillierte Dokumentation
```

## Erste Schritte

Für eine detaillierte Anleitung zur Einrichtung und Verwendung des Clusters, siehe die [Setup-Dokumentation](docs/setup.md).

## Dokumentation

Dieses Projekt enthält umfangreiche Dokumentation im `docs/`-Verzeichnis:

- [**Architektur**](docs/architecture.md): Vollständige Cluster-Architektur
- [**Vereinfachte Architektur**](docs/architecture-simple.md): Vereinfachte Version für schnelles Deployment
- [**Setup-Anleitung**](docs/setup.md): Detaillierte Einrichtungsanleitung
- [**Sicherheit**](docs/security.md): Sicherheitshinweise und Best Practices
- [**ACR-Integration**](docs/acr-integration.md): Azure Container Registry Integration
- [**Nomad vs. Kubernetes**](docs/nomad-vs-kubernetes-praesentation.md): Vergleich der Orchestrierungsplattformen

## Verwendete Technologien

- [HashiCorp Nomad](https://www.nomadproject.io/)
- [HashiCorp Consul](https://www.consul.io/)
- [Terraform](https://www.terraform.io/)
- [Ansible](https://www.ansible.com/)
- [Azure Cloud](https://azure.microsoft.com/)
- [GitHub Actions](https://github.com/features/actions)

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.
