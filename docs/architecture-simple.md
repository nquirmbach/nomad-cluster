# Vereinfachte Nomad Cluster Architektur (Dev/Test)

## Überblick

Diese vereinfachte Architektur fokussiert sich auf schnelles Setup via GitHub Actions mit minimaler Komplexität. Security Features werden dokumentiert aber nicht initial implementiert.

## Architektur-Komponenten (Simplified)

### 1. Netzwerk-Architektur

#### Virtual Network (VNet)

- **Address Space**: 10.0.0.0/16
- **Subnets**:
  - **Cluster Subnet**: 10.0.10.0/24 (Server + Client Nodes)
  - **Bastion Subnet**: 10.0.20.0/27 (Azure Bastion Service)

#### Load Balancer

- **Type**: Azure Standard Load Balancer
- **Public IP**: Eine öffentliche IP für alle Services
- **Frontend Configuration**:
  - Port 4646 → Nomad UI/API (load-balanced über alle Server)
  - Port 8500 → Consul UI (load-balanced über alle Server)
  - Ports 50001-50003 → SSH NAT Rules (ein Port pro Server)
- **Backend Pool**: Alle Nomad Server Nodes
- **Health Probes**:
  - Nomad: HTTP GET `/v1/status/leader` auf Port 4646
  - Consul: HTTP GET `/v1/status/leader` auf Port 8500

#### Network Security Groups (NSGs)

- **Server NSG**:
  - Erlaubt 4646 (Nomad HTTP API) - vom Load Balancer
  - Erlaubt 4647-4648 (Nomad RPC, Serf) - intern
  - Erlaubt 22 (SSH) - vom Load Balancer (NAT Rules)
  - Erlaubt 8500 (Consul HTTP API) - vom Load Balancer
  - Erlaubt 8301-8302 (Consul Serf) - intern
- **Client NSG**:
  - Erlaubt alle Ports - intern (für Nomad Jobs)
  - Erlaubt 22 (SSH) - intern für Management

### 2. Compute-Ressourcen

#### Nomad Server Nodes

- **VM Typ**: Standard_B2s (2 vCPU, 4 GB RAM) - Cost-optimized
- **Anzahl**: 3 Nodes (für Consensus)
- **OS**: Ubuntu 22.04 LTS
- **Managed Disks**: Standard SSD (E10: 128 GB)
- **Networking**: 
  - Private IPs nur (10.0.10.x)
  - Zugriff via Load Balancer
  - SSH via NAT Rules (Ports 50001-50003)

#### Nomad Client Nodes

- **VM Typ**: Standard_B2ms (2 vCPU, 8 GB RAM)
- **Anzahl**: 2+ Nodes (via VMSS Auto-Scaling)
- **OS**: Ubuntu 22.04 LTS
- **Managed Disks**: Standard SSD (E10: 128 GB)
- **Networking**: 
  - Private IPs nur (10.0.10.x)
  - Kein direkter Internet-Zugriff
  - Kommunikation über VNet intern
- **Scaling**: Azure Virtual Machine Scale Sets (VMSS)
  - Standard Azure VMSS Auto-Scaling (CPU-basiert)
  - Erweiterbar mit [Nomad Autoscaler für Azure VMSS](https://developer.hashicorp.com/nomad/tools/autoscaling/plugins/target/azure-vmss) für workload-basiertes Scaling
- **Konfiguration**: Cloud-Init (automatisch beim Boot)
  - Installiert Nomad Client und Docker
  - Konfiguriert Verbindung zu Servern
  - Startet Nomad Service
  - Kein Ansible-Zugriff nötig
- **Container Registry**: 
  - Azure Container Registry (ACR) Integration
  - Managed Identity für ACR Pull-Zugriff
  - Docker-Treiber mit ACR-Authentifizierung

#### Storage Account für Artifacts

- **Type**: Azure Storage Account (Standard LRS)
- **Container**: `artifacts` (public blob access)
- **Verwendung**:
  - Speicherung von Deployment-Artifacts (z.B. .NET Executables)
  - Öffentlicher Zugriff für Nomad Artifact Downloads
  - RBAC-Integration mit GitHub Actions
- **Sicherheit**:
  - **HINWEIS**: Öffentlicher Blob-Zugriff nur für Testzwecke!
  - In Enterprise-Szenarien sollte der Storage Account nur innerhalb des Cluster-Netzwerks zugänglich sein
  - Private Endpoints oder Service Endpoints verwenden
  - Zugriff über Managed Identities oder SAS-Tokens mit begrenzter Lebensdauer
  - Verschlüsselung im Ruhezustand (Azure Storage Encryption)

#### Consul (Optional, aber empfohlen)

- **Co-located**: Auf Nomad Server Nodes installiert
- **3 Consul Server** (co-located mit Nomad Servern)

### 3. Vereinfachungen gegenüber Production

**Weggelassen**:

- ❌ Availability Zones (Single Zone)
- ❌ Separate Subnets für Server und Clients (ein gemeinsames Cluster Subnet)
- ❌ NAT Gateway (Clients ohne Internet-Zugriff)

**Implementiert**:

- ✅ Infrastructure as Code (Terraform)
- ✅ Configuration Management (Ansible)
- ✅ Consul für Service Discovery
- ✅ Managed Disks
- ✅ NSG für Basic Security
- ✅ Load Balancer mit NAT Rules
- ✅ Private IPs für alle VMs
- ✅ Key Vault (für Secrets Management)
- ✅ Multi-Server HA (3 Server für Consensus)
- ✅ VMSS Auto-Scaling für Client Nodes
- ✅ Log Analytics Workspace (für zentrales Logging)
- ✅ Azure Bastion Service (für sicheren SSH-Zugriff)
- ✅ Storage Account für Artifacts (für Executable Deployments)
  - ⚠️ **Hinweis**: Öffentlicher Blob-Zugriff nur für Testzwecke! In Enterprise-Umgebungen sollten Private/Service Endpoints verwendet werden.

## Konfigurationsmethodik

Die Cluster-Komponenten werden über verschiedene Methoden konfiguriert:

### Server-Konfiguration
- **Methode**: Ansible über GitHub Actions
- **Zugriff**: 
  - SSH über Load Balancer NAT Rules (Ports 50001-50003)
  - SSH über Azure Bastion Service (sicherer)
- **Playbooks**: 
  - `common.yml`: Basis-Setup für alle Nodes
  - `consul.yml`: Consul Server Installation und Konfiguration
  - `nomad-server.yml`: Nomad Server Installation und Konfiguration

### Client-Konfiguration
- **Methode**: Cloud-Init (automatisch beim VM-Start)
- **Vorteile**:
  - Kein SSH-Zugriff erforderlich
  - Skaliert automatisch mit VMSS
  - Parallele Konfiguration aller Instances
  - Keine Abhängigkeit von externem Zugriff
- **Komponenten**:
  - Nomad Client Installation
  - Systemd Service Konfiguration
  - Verbindung zu Servern über Load Balancer

## Architektur-Diagramm (Simplified)

```
┌───────────────────────────────────────────────────────┐
│                  Azure Subscription                   │
│                                                       │
│  ┌─────────────────────────────────┐                 │
│  │      Load Balancer (Public)     │                 │
│  │  ┌──────────────────────────┐   │                 │
│  │  │ Public IP: x.x.x.x       │   │                 │
│  │  │ - Port 4646 → Nomad UI   │   │                 │
│  │  │ - Port 8500 → Consul UI  │   │                 │
│  │  │ - Port 50001-3 → SSH NAT │   │                 │
│  │  └──────────────────────────┘   │                 │
│  └──────────────┬──────────────────┘                 │
│                 │                                     │
│  ┌──────────────▼──────────────────────────────────┐ │
│  │         Virtual Network (10.0.0.0/16)           │ │
│  │                                                 │ │
│  │  ┌──────────────────────────────────────────┐  │ │
│  │  │    Cluster Subnet (10.0.10.0/24)        │  │ │
│  │  │                                          │  │ │
│  │  │  ┌──────────────┐ ┌──────────────┐      │  │ │
│  │  │  │ Nomad Server │ │ Nomad Server │      │  │ │
│  │  │  │  + Consul 1  │ │  + Consul 2  │      │  │ │
│  │  │  │ Private IP   │ │ Private IP   │      │  │ │
│  │  │  └──────────────┘ └──────────────┘      │  │ │
│  │  │         ┌──────────────┐                │  │ │
│  │  │         │ Nomad Server │                │  │ │
│  │  │         │  + Consul 3  │                │  │ │
│  │  │         │ Private IP   │                │  │ │
│  │  │         └──────────────┘                │  │ │
│  │  │               ↑                          │  │ │
│  │  │               │ Internal Communication   │  │ │
│  │  │          ┌────┴────┐                    │  │ │
│  │  │          │         │                    │  │ │
│  │  │  ┌───────┴──────┐                      │  │ │
│  │  │  │   VMSS       │                      │  │ │
│  │  │  │  Clients     │                      │  │ │
│  │  │  │ (Auto-Scale) │                      │  │ │
│  │  │  └──────────────┘                      │  │ │
│  │  │                                          │  │ │
│  │  └──────────────────────────────────────────┘  │ │
│  │                                                 │ │
│  │  ┌──────────────────────────────────────────┐  │ │
│  │  │    Bastion Subnet (10.0.20.0/27)        │  │ │
│  │  │                                          │  │ │
│  │  │  ┌──────────────────────────┐           │  │ │
│  │  │  │ Azure Bastion Service    │           │  │ │
│  │  │  │ (Secure SSH Access)      │           │  │ │
│  │  │  └──────────────────────────┘           │  │ │
│  │  │                                          │  │ │
│  │  └──────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────┐  │
│  │ Storage      │  │ Resource Group │  │Key Vault│  │
│  │ Account      │  │  (Terraform    │  │         │  │
│  │ (TF State)   │  │   State)       │  │         │  │
│  └──────────────┘  └────────────────┘  └─────────┘  │
│                                                       │
│  ┌──────────────┐                                  │
│  │ Storage      │                                  │
│  │ Account      │                                  │
│  │ (Artifacts)  │                                  │
│  └──────────────┘                                  │
│                                                       │
│  ┌────────────────┐                                 │
│  │ Log Analytics  │                                 │
│  │   Workspace    │                                 │
│  └────────────────┘                                 │
└───────────────────────────────────────────────────────┘

         ↑
         │ GitHub Actions Deploy
         │
┌────────┴─────────┐
│  GitHub Repo     │
│  .github/        │
│  workflows/      │
└──────────────────┘
```

## Resource Gruppen Struktur

```
nomad-cluster-dev-rg        # Alle Cluster-Ressourcen
nomad-tfstate-rg            # Terraform State Storage
```

## Terraform Struktur (Simplified)

```
terraform/
├── main.tf                  # Main resources
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars         # Variable values (gitignored)
├── terraform.tfvars.example # Template
└── versions.tf              # Provider versions

ansible/
├── inventory.ini            # Static inventory (generiert von Terraform)
├── ansible.cfg
├── playbooks/
│   ├── nomad-server.yml
│   ├── nomad-client.yml
│   └── consul.yml
└── roles/
    ├── common/
    ├── nomad/
    └── consul/
```

## GitHub Actions Workflows

### Workflow 1: Cluster Provisioning

**Datei**: `.github/workflows/provision-cluster.yml`

**Trigger**:

- Manual (workflow_dispatch)
- Push auf `main` Branch (terraform/ Änderungen)

**Steps**:

1. Checkout Repository
2. Setup Terraform
3. Azure Login (via Service Principal)
4. Terraform Init (mit Remote State)
5. Terraform Plan
6. Terraform Apply
7. Generate Ansible Inventory
8. Setup Ansible
9. Run Ansible Playbooks
10. Output Cluster Info

**Secrets benötigt** (pro Environment):

- `AZURE_CLIENT_ID` - Managed Identity Client ID
- `AZURE_TENANT_ID` - Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

**Authentifizierung**: OIDC (Federated Identity) - keine Passwörter/Secrets nötig!

### Workflow 2: App Deployment

**Datei**: `.github/workflows/deploy-app.yml`

**Trigger**:

- Manual (workflow_dispatch)
- Push auf `main` Branch (apps/ Änderungen)

**Steps**:

1. Checkout Repository
2. Setup Nomad CLI
3. Get Nomad Server IP (from Azure)
4. Validate Nomad Job Files
5. Deploy Jobs to Nomad
6. Verify Deployment Status

**Secrets benötigt**:

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `NOMAD_ADDR` (dynamisch ermittelt oder gespeichert)

## Kosten-Schätzung (Monatlich)

### Simplified Dev/Test Setup

- **3x Nomad Server** (Standard_B2s): ~€90
- **2-4x Nomad Client** (Standard_B2ms via VMSS): ~€60-120
- **Load Balancer** (Standard): ~€20
- **Azure Bastion Service** (Standard): ~€150
- **Networking** (VNet, NSG, 2 Public IPs): ~€10
- **Storage** (Standard SSD): ~€25
- **Key Vault**: ~€5
- **Log Analytics Workspace**: ~€10
- **Terraform State Storage**: ~€2
- **Gesamt**: **~€350-410/Monat**

**Kosteneinsparung durch Load Balancer**: ~€10/Monat (weniger Public IPs)

**Hinweis**: Bei Nicht-Nutzung können VMs gestoppt werden (nur Storage-Kosten ~€17/Monat)

## Deployment Flow

```
┌──────────────────┐
│  Developer       │
│  pushes code     │
└────────┬─────────┘
         │
         ▼
┌────────────────────────────────────────┐
│  GitHub Actions                         │
│  Workflow: provision-cluster.yml        │
│                                         │
│  1. Terraform Apply                     │
│     ├─ Create VNet + NSG               │
│     ├─ Create VMs (1 Server, 2 Client) │
│     └─ Output IPs                       │
│                                         │
│  2. Ansible Provisioning                │
│     ├─ Install Docker                   │
│     ├─ Install Consul                   │
│     ├─ Install Nomad                    │
│     ├─ Configure Services               │
│     └─ Start Services                   │
└────────┬───────────────────────────────┘
         │
         ▼
┌─────────────────────┐
│  Nomad Cluster      │
│  ✓ Ready            │
│  ✓ Server: Running  │
│  ✓ Clients: 2/2     │
└─────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│  GitHub Actions                 │
│  Workflow: deploy-app.yml       │
│                                 │
│  1. Get Cluster Info            │
│  2. Validate Job Spec           │
│  3. Deploy to Nomad             │
│  4. Verify Status               │
└────────┬───────────────────────┘
         │
         ▼
┌─────────────────────┐
│  App Running        │
│  on Nomad Cluster   │
└─────────────────────┘
```

## Access & Testing

### Nomad UI

```
http://<server-public-ip>:4646/ui
```

### Consul UI

```
http://<server-public-ip>:8500/ui
```

### CLI Access

```bash
export NOMAD_ADDR=http://<server-public-ip>:4646
nomad status
```

### SSH Access

**Option 1: Load Balancer NAT Rules**
```bash
ssh -i ~/.ssh/nomad-cluster-key azureuser@<load-balancer-ip> -p 5000X
```
Wobei X = 1, 2 oder 3 für die jeweilige Server-Instanz.

**Option 2: Azure Bastion (empfohlen)**

Über das Azure Portal oder die Azure CLI:
```bash
az network bastion ssh --name <bastion-name> --resource-group <resource-group> --target-resource-id <vm-resource-id> --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/nomad-cluster-key
```

## Upgrade Path zu Production

Wenn das Setup produktiv werden soll, folgende Schritte:

1. **High Availability**: 3-5 Server Nodes + Load Balancer
2. **Security**: Azure Bastion, Private IPs, Key Vault
3. **Network Segmentation**: Separate Subnets + NSG Hardening
4. **Availability Zones**: Multi-AZ Deployment
5. **Auto-Scaling**: VMSS für Clients
6. **Monitoring**: Log Analytics + Alerting
7. **Backup**: Automatische Snapshots
8. **TLS/ACL**: Verschlüsselung + Access Control

Siehe `docs/architecture.md` für vollständige Production-Architektur.

## Limitations & Trade-offs

**Eingeschränkte HA**:

- 3 Server bieten Basis-HA, aber keine AZ-Redundanz
- Bei Zone-Ausfall: Cluster eventuell nicht verfügbar
- Quorum erfordert mindestens 2 funktionierende Server

**Public IPs und Storage**:

- Security Risk (aber durch NSG eingeschränkt)
- Öffentlicher Storage Account für Artifacts ist ein Sicherheitsrisiko
- In Enterprise-Umgebungen sollten Private Endpoints oder Service Endpoints verwendet werden
- Produktiv nicht empfohlen
- Nur für Testing/Dev akzeptabel

**VMSS Scaling**:

- Auto-Scaling basierend auf CPU/Memory möglich
- Scaling Rules müssen konfiguriert werden
- Scale-In/Out Limits definieren

**Monitoring mit Log Analytics**:

- Zentrales Logging über Log Analytics Workspace
- Basis-Monitoring für VMs und Infrastruktur
- Alerts müssen manuell konfiguriert werden
- Kein Application-Level Monitoring

**No Disaster Recovery**:

- Keine automatischen Backups
- Kein Multi-Region Setup
- Recovery nur via Terraform Re-Deploy

## Security Hinweise (für spätere Implementierung)

Siehe `docs/security-hardening.md` für Details zu:

- TLS Encryption (Nomad, Consul)
- ACL Tokens
- Network Security (Private IPs, Bastion)
- Secrets Management (Key Vault)
- OS Hardening
- Compliance Requirements

## Nächste Schritte

1. ✅ Architektur geplant
2. ⏭️ GitHub Actions Workflows erstellen
3. ⏭️ Terraform Module entwickeln
4. ⏭️ Ansible Playbooks erstellen
5. ⏭️ Test Deployment durchführen
