# GitHub und Azure Setup für Nomad Cluster

Diese Dokumentation beschreibt alle notwendigen Schritte, um die Azure-Umgebung und GitHub für die automatisierte Bereitstellung des Nomad Clusters einzurichten.

## Setup-Übersicht

### Was wird von wem erstellt?

| Komponente | Wer erstellt | Wann | Wie |
|------------|--------------|------|-----|
| **Terraform Backend Storage** | Administrator (manuell) | Einmalig vor erstem Deployment | Azure CLI |
| **Resource Group** | Setup-Script | Pro Environment (dev/stg/prd) | `setup-federated-identity.sh` |
| **Managed Identity** | Setup-Script | Pro Environment | `setup-federated-identity.sh` |
| **Federated Identity Credential** | Setup-Script | Pro Environment | `setup-federated-identity.sh` |
| **RBAC auf Resource Group** | Setup-Script | Pro Environment | `setup-federated-identity.sh` |
| **RBAC auf Backend Storage** | Setup-Script | Pro Environment | `setup-federated-identity.sh` |
| **GitHub Environments** | Setup-Script (automatisch) | Pro Environment | `setup-federated-identity.sh` + GitHub CLI |
| **GitHub Secrets** | Setup-Script (automatisch) | Pro Environment | `setup-federated-identity.sh` + GitHub CLI |
| **OIDC Aktivierung** | Administrator (manuell) | Einmalig | GitHub Repository Settings |
| **ACR** | Terraform (Pipeline) | Pro Environment | GitHub Actions Workflow |
| **VMs, NSGs, VNet, etc.** | Terraform (Pipeline) | Pro Environment | GitHub Actions Workflow |
| **Nomad/Consul Installation** | Ansible (Pipeline) | Pro Environment | GitHub Actions Workflow |

### Setup-Reihenfolge

1. ✅ **Terraform Backend** (einmalig, manuell via Azure CLI)
2. ✅ **GitHub CLI Setup** (einmalig, manuell - optional für automatische GitHub-Konfiguration)
3. ✅ **Federated Identity Setup** (pro Environment, automatisch via Script)
4. ✅ **OIDC Aktivierung** (einmalig, manuell in GitHub Settings)
5. ✅ **Deployment via Pipeline** (pro Environment, automatisch)

## Technologie-Stack

Für die automatisierte Bereitstellung des Nomad Clusters mit GitHub Actions und Azure verwenden wir:

- **Federated Identity (OIDC)** für sichere Authentifizierung ohne gespeicherte Secrets
- **Terraform Workspaces** für Multi-Environment-Deployments (dev, stg, prd)
- **Azure Storage Backend** für zentrales State Management
- **GitHub Actions** für CI/CD Pipeline
- **Ansible** für Konfigurationsmanagement

![Federated Identity Architektur](https://learn.microsoft.com/de-de/azure/developer/github/media/github-actions/federated-identity-credential-flow.png)

## 0. Terraform Backend einrichten (einmalig)

Erstelle den Azure Storage Account für den Terraform State:

```bash
# Resource Group für Terraform State erstellen
az group create --name tf-state-rg --location westeurope

# Storage Account erstellen
az storage account create \
  --name tfstatenomadcluster \
  --resource-group tf-state-rg \
  --location westeurope \
  --sku Standard_LRS

# Container für State Files erstellen
az storage container create \
  --name tfstate \
  --account-name tfstatenomadcluster
```

## Client provisioning (cloud-init via templatefile)

This project provisions Nomad clients via cloud-init using a reusable template.

- **Template path**: `terraform/modules/compute/templates/nomad-client-cloud-init.yaml.tftpl`
- **Terraform usage**:
  ```hcl
  custom_data = base64encode(
    templatefile("${path.module}/templates/nomad-client-cloud-init.yaml.tftpl", {
      server_ips         = [for s in azurerm_linux_virtual_machine.nomad_server : s.private_ip_address],
      datacenter         = var.datacenter,
      nomad_version      = var.nomad_version,
      acr_login_server   = var.acr_login_server,
      acr_admin_username = var.acr_admin_username,
      acr_admin_password = var.acr_admin_password
    })
  )
  ```
- **Dynamic server list**: The template renders the `client.servers` array using a loop over `server_ips`.
- **Docker/ACR auth**: The template creates `/etc/docker/config.json` with admin credentials for ACR.
  - Required permissions: `/etc/docker` → `755`, `/etc/docker/config.json` → `644`, owner `root:root`.
  - Nomad Docker plugin references the file:
    ```hcl
    plugin "docker" {
      config { auth { config = "/etc/docker/config.json" } }
    }
    ```
- **Service**: `nomad-client` runs as root to access Docker. Verify with:
  ```bash
  systemctl status nomad-client
  nomad node status -self
  ```

**Hinweis**: Dieser Schritt muss nur einmal durchgeführt werden. Der Storage Account wird von allen Environments (dev, stg, prd) genutzt.

## 1. Azure-Ressourcen einrichten

### Terraform Workspaces

Das Projekt nutzt Terraform Workspaces für verschiedene Umgebungen:

- **dev** - Development
- **stg** - Staging
- **prd** - Production

Jedes Workspace hat:

- Eigene Resource Group: `rg-nomad-cluster-{env}`
- Eigenen Ressourcen-Prefix: `nmdclstr-{env}`
- Eigene Managed Identity
- Eigenes GitHub Environment: `{env}` (dev, stg, prd)

### Option A: Verwendung des Setup-Scripts (empfohlen)

Das bereitgestellte Script erstellt automatisch alle erforderlichen Azure-Ressourcen für eine Umgebung:

```bash
# Script ausführbar machen
chmod +x scripts/setup-federated-identity.sh

# Development-Umgebung einrichten
./scripts/setup-federated-identity.sh --env dev

# Staging-Umgebung einrichten
./scripts/setup-federated-identity.sh --env stg

# Production-Umgebung einrichten
./scripts/setup-federated-identity.sh --env prd
```

Das Script erstellt pro Umgebung automatisch:

**Azure-Ressourcen:**
- Resource Group `rg-nomad-cluster-{env}`
- User-Assigned Managed Identity
- Federated Identity Credential (OIDC)
- RBAC Contributor auf Resource Group
- RBAC Storage Blob Data Contributor auf Backend Storage Account

**GitHub-Ressourcen (bei installierter GitHub CLI):**
- GitHub Environment (`dev`, `stg`, `prd`)
- Environment Secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

**Voraussetzungen:**
- Azure CLI installiert und angemeldet (`az login`)
- GitHub CLI installiert und angemeldet (`gh auth login`) - optional, aber empfohlen

### Option B: Manuelle Einrichtung

Falls du die Ressourcen manuell erstellen möchtest, führe folgende Schritte aus:

1. **Resource Group erstellen**:

   ```bash
   az group create --name rg-nomad-cluster-dev --location westeurope
   ```

2. **Azure Container Registry erstellen**:

   ```bash
   az acr create --resource-group rg-nomad-cluster-dev --name nomadacr --sku Standard --admin-enabled false
   ```

3. **User-Assigned Managed Identity erstellen**:

   ```bash
   az identity create --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev
   ```

4. **Principal ID und Client ID abrufen**:

   ```bash
   PRINCIPAL_ID=$(az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev --query principalId -o tsv)
   CLIENT_ID=$(az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev --query clientId -o tsv)
   ```

5. **Federated Identity Credential erstellen**:

   ```bash
   az identity federated-credential create \
     --name nomad-github-actions-federated \
     --identity-name nomad-github-actions-identity \
     --resource-group rg-nomad-cluster-dev \
     --audience "api://AzureADTokenExchange" \
     --issuer "https://token.actions.githubusercontent.com" \
     --subject "repo:nquirmbach/nomad-cluster:environment:azure-dev"
   ```

6. **RBAC-Berechtigungen für ACR zuweisen**:

   ```bash
   ACR_ID=$(az acr show --name nomadacr --resource-group rg-nomad-cluster-dev --query id -o tsv)
   az role assignment create --assignee "$PRINCIPAL_ID" --role "AcrPush" --scope "$ACR_ID"
   ```

7. **RBAC-Berechtigungen für Resource Group zuweisen**:

   ```bash
   RG_ID=$(az group show --name rg-nomad-cluster-dev --query id -o tsv)
   az role assignment create --assignee "$PRINCIPAL_ID" --role "Reader" --scope "$RG_ID"
   ```

8. **RBAC-Berechtigungen für VM-Zugriff zuweisen**:
   ```bash
   SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   VM_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-nomad-cluster-dev/providers/Microsoft.Compute/virtualMachines/*"
   az role assignment create --assignee "$PRINCIPAL_ID" --role "Virtual Machine User Login" --scope "$VM_SCOPE"
   ```

## 2. GitHub CLI Setup (optional, aber empfohlen)

Für die automatische Erstellung von GitHub Environments und Secrets:

```bash
# GitHub CLI installieren
# macOS:
brew install gh

# Linux:
sudo apt install gh

# Windows:
winget install --id GitHub.cli

# Authentifizieren
gh auth login
```

**Hinweis**: Falls GitHub CLI nicht installiert ist, zeigt das Setup-Script die Werte an, die manuell in GitHub hinzugefügt werden müssen.

## 3. GitHub Repository konfigurieren

### 3.1 OIDC Aktivierung (einmalig, manuell erforderlich)

1. Gehe zu **Settings** > **Actions** > **General**
2. Unter "Workflow permissions":
   - Aktiviere **Read and write permissions**
   - Aktiviere **Allow GitHub Actions to create and approve pull requests**
3. Unter "OpenID Connect":
   - Aktiviere **Allow GitHub Actions to request the OpenID Connect ID token**
4. Klicke auf **Save**

### 3.2 Deployment Protection Rules (optional)

Für zusätzliche Sicherheit in Production:

1. Gehe zu **Settings** > **Environments** > **prd**
2. Aktiviere **Required reviewers**
3. Füge Reviewer hinzu, die Deployments genehmigen müssen

## 4. Terraform Workspaces verwenden

### 4.1 Lokale Verwendung

```bash
cd terraform

# Initialisieren
terraform init

# Workspace erstellen/wechseln
terraform workspace new dev
terraform workspace select dev

# Deployment
terraform plan
terraform apply

# Für andere Umgebungen
terraform workspace select stg
terraform workspace select prd
```

### 4.2 Environment-spezifische Konfiguration

Jedes Environment kann eigene Terraform-Variablen haben:

```
terraform/
├── terraform.tfvars                    # Basis-Konfiguration
└── environments/
    ├── dev/terraform.tfvars           # Dev-spezifische Werte
    ├── stg/terraform.tfvars           # Staging-spezifische Werte
    └── prd/terraform.tfvars           # Production-spezifische Werte
```

Beispiel für `environments/prd/terraform.tfvars`:
```hcl
server_count = 5
client_count = 10

tags = {
  Environment = "Prod"
  Project     = "NomadCluster"
  ManagedBy   = "Terraform"
  Owner       = "YourName"
}
```

### 4.3 GitHub Actions Workflow

Der Workflow `.github/workflows/provision-cluster.yml` unterstützt Multi-Environment-Deployments:

1. Gehe zu **Actions** > **Provision Nomad Cluster**
2. Klicke auf **Run workflow**
3. Wähle das gewünschte **Environment** (dev/stg/prd)
4. Wähle die **Action** (apply/destroy)
5. Klicke auf **Run workflow**

Der Workflow:
- Wählt automatisch das richtige GitHub Environment (`dev`, `stg`, `prd`)
- Authentifiziert sich via OIDC mit der entsprechenden Managed Identity
- Wechselt zum entsprechenden Terraform Workspace
- Führt die gewählte Aktion aus

```yaml
name: Provision Nomad Cluster

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment (Terraform Workspace)'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - stg
          - prd
      action:
        description: 'Action to perform'
        required: true
        default: 'apply'
        type: choice
        options:
          - apply
          - destroy

jobs:
  provision:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login mit OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Select Terraform Workspace
        run: |
          terraform workspace select ${{ github.event.inputs.environment }} || \
          terraform workspace new ${{ github.event.inputs.environment }}
      
      # Weitere Schritte für Terraform und Ansible...
```

### 3.2 App-Deployment Workflow

Der Workflow `.github/workflows/deploy-app.yml` verwendet ebenfalls die Federated Identity:

```yaml
name: Deploy Application to Nomad

on:
  workflow_dispatch:
    inputs:
      job_file:
        description: "Path to Nomad job file"
        required: true
        default: "jobs/example.nomad"

jobs:
  build:
    runs-on: ubuntu-latest
    environment: azure-dev

    steps:
      - uses: actions/checkout@v4

      - name: Azure Login mit OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: ACR Login mit Azure CLI
        run: |
          RESOURCE_GROUP="${{ secrets.NOMAD_RESOURCE_GROUP }}"
          ACR_NAME="${{ secrets.ACR_NAME }}"
          az acr login --name $ACR_NAME

      # Weitere Schritte für Docker Build und Nomad Deployment...
```

## 4. Überprüfung der Einrichtung

Nach Abschluss der Einrichtung kannst du die Konfiguration überprüfen:

1. **Azure-Ressourcen überprüfen**:

   ```bash
   # Managed Identity überprüfen
   az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev

   # Federated Credential überprüfen
   az identity federated-credential list --identity-name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev

   # RBAC-Zuweisungen überprüfen
   az role assignment list --assignee <principal-id>
   ```

2. **GitHub Actions Workflow testen**:
   - Gehe zu **Actions** im GitHub Repository
   - Wähle den Workflow "Provision Nomad Cluster"
   - Klicke auf **Run workflow**
   - Überprüfe, ob der Workflow erfolgreich ausgeführt wird

## Komplette Setup-Anleitung (Schritt für Schritt)

### Einmalige Vorbereitung

1. **Terraform Backend erstellen**:
   ```bash
   az group create --name tf-state-rg --location westeurope
   az storage account create --name tfstatenomadcluster --resource-group tf-state-rg --sku Standard_LRS
   az storage container create --name tfstate --account-name tfstatenomadcluster
   ```

2. **GitHub CLI installieren und authentifizieren** (optional, aber empfohlen):
   ```bash
   # Installation (macOS)
   brew install gh
   
   # Authentifizierung
   gh auth login
   ```

3. **OIDC in GitHub aktivieren**:
   - Gehe zu Settings → Actions → General
   - Aktiviere "Allow GitHub Actions to request the OpenID Connect ID token"

### Pro Environment (dev, stg, prd)

1. **Setup-Script ausführen**:
   ```bash
   chmod +x scripts/setup-federated-identity.sh
   ./scripts/setup-federated-identity.sh --env dev
   ```
   
   Das Script erstellt automatisch:
   - ✅ Azure Resource Group
   - ✅ Managed Identity
   - ✅ Federated Identity Credential
   - ✅ RBAC-Berechtigungen
   - ✅ GitHub Environment (bei installierter GitHub CLI)
   - ✅ GitHub Secrets (bei installierter GitHub CLI)

2. **Environment-spezifische Terraform-Variablen anpassen** (optional):
   - Bearbeite `terraform/environments/{env}/terraform.tfvars`
   - Passe Werte wie `server_count`, `client_count`, `tags` an

3. **Deployment starten**:
   - Gehe zu Actions → "Provision Nomad Cluster"
   - Klicke "Run workflow"
   - Wähle Environment: `dev`
   - Wähle Action: `apply`

### Für weitere Environments

Wiederhole die Schritte unter "Pro Environment" mit `--env stg` oder `--env prd`.

## Fehlerbehebung

### Häufige Probleme

1. **Authentifizierungsfehler**:
   - Überprüfe, ob der Environment-Name in GitHub korrekt ist (`dev`, `stg`, `prd`)
   - Stelle sicher, dass die OIDC-Berechtigungen aktiviert sind
   - Prüfe, ob die Secrets im richtigen Environment hinterlegt sind

2. **Berechtigungsfehler**:
   - Überprüfe, ob die RBAC-Rollen korrekt zugewiesen sind
   - Stelle sicher, dass die Managed Identity Contributor-Rechte auf die Resource Group hat
   - Prüfe Storage Blob Data Contributor auf Backend Storage Account

3. **Terraform State Lock**:
   - Falls ein State Lock hängt: `terraform force-unlock <LOCK_ID>`
   - Prüfe RBAC auf Storage Account

### Debugging-Befehle

```bash
# Azure Login überprüfen
az account show

# Managed Identity Details anzeigen
az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev

# RBAC-Zuweisungen anzeigen
PRINCIPAL_ID=$(az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev --query principalId -o tsv)
az role assignment list --assignee "$PRINCIPAL_ID"
```

## Vorteile der Federated Identity

- **Keine Secrets**: Keine Client Secrets oder Passwörter müssen gespeichert werden
- **Automatische Rotation**: Kurzlebige Tokens werden automatisch generiert
- **Granulare Kontrolle**: Tokens können auf bestimmte Workflows, Branches oder Environments beschränkt werden
- **Audit-Trail**: Bessere Nachvollziehbarkeit der Authentifizierungsvorgänge
- **Reduziertes Risiko**: Kein Risiko durch kompromittierte langlebige Credentials
