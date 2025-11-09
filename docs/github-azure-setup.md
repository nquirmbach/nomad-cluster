# GitHub und Azure Setup für Nomad Cluster

Diese Dokumentation beschreibt alle notwendigen Schritte, um die Azure-Umgebung und GitHub für die automatisierte Bereitstellung des Nomad Clusters einzurichten.

## Übersicht

Für die automatisierte Bereitstellung des Nomad Clusters mit GitHub Actions und Azure verwenden wir:

- **Federated Identity (OIDC)** für sichere Authentifizierung ohne gespeicherte Secrets
- **Terraform Workspaces** für Multi-Environment-Deployments (dev, stg, prd)
- **Azure Storage Backend** für zentrales State Management

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
- Eigenes GitHub Environment: `azure-{env}`

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

Das Script erstellt pro Umgebung:

- Resource Group `rg-nomad-cluster-{env}`
- User-Assigned Managed Identity
- Federated Identity Credential
- RBAC-Zuweisungen für die benötigten Berechtigungen

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

## 2. GitHub Repository konfigurieren

Nach der Einrichtung der Azure-Ressourcen müssen folgende Schritte im GitHub Repository durchgeführt werden.

### 2.1 Environments erstellen

Erstelle für jede Umgebung ein separates GitHub Environment:

1. Navigiere zu deinem Repository auf GitHub
2. Gehe zu **Settings** > **Environments**
3. Erstelle folgende Environments:
   - `azure-dev` (Development)
   - `azure-stg` (Staging)
   - `azure-prd` (Production)
4. Optional: Konfiguriere Deployment Protection Rules
   - Für `azure-prd`: Required Reviewers aktivieren
   - Für `azure-stg`: Optional Required Reviewers
   - Für `azure-dev`: Keine Einschränkungen

### 2.2 Environment Secrets hinzufügen

Füge die Secrets **pro Environment** hinzu:

1. Navigiere zu **Settings** > **Environments**
2. Wähle ein Environment (z.B. `azure-dev`)
3. Unter "Environment secrets" füge folgende Secrets hinzu:

   | Secret Name | Wert | Beschreibung |
   |-------------|------|-------------|
   | `AZURE_CLIENT_ID` | Client ID der Managed Identity | Ausgabe des Setup-Scripts für dieses Environment |
   | `AZURE_TENANT_ID` | Tenant ID deines Azure-Kontos | Ausgabe von `az account show --query tenantId -o tsv` |
   | `AZURE_SUBSCRIPTION_ID` | Subscription ID | Ausgabe von `az account show --query id -o tsv` |
   | `NOMAD_RESOURCE_GROUP`  | `rg-nomad-cluster-dev`         | Name der Resource Group                               |
   | `ACR_NAME`              | `nomadacr`                     | Name der Azure Container Registry                     |

**Wichtig**: Jedes Environment (`azure-dev`, `azure-stg`, `azure-prd`) benötigt seine eigenen Secrets mit der jeweiligen Client ID der Managed Identity für diese Umgebung.

### 2.3 Workflow-Berechtigungen aktivieren

1. Gehe zu **Settings** > **Actions** > **General**
2. Unter "Workflow permissions":
   - Aktiviere **Read and write permissions**
   - Aktiviere **Allow GitHub Actions to create and approve pull requests**
3. Unter "OpenID Connect":
   - Aktiviere **Allow GitHub Actions to request the OpenID Connect ID token**
4. Klicke auf **Save**

## 3. Terraform Workspaces verwenden

### 3.1 Lokale Verwendung

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

### 3.2 GitHub Actions Workflow

Der Workflow `.github/workflows/provision-cluster.yml` unterstützt Multi-Environment-Deployments:

1. Gehe zu **Actions** > **Provision Nomad Cluster**
2. Klicke auf **Run workflow**
3. Wähle das gewünschte **Environment** (dev/stg/prd)
4. Wähle die **Action** (apply/destroy)
5. Klicke auf **Run workflow**

Der Workflow:
- Wählt automatisch das richtige GitHub Environment (`azure-dev`, `azure-stg`, `azure-prd`)
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
    environment: azure-${{ github.event.inputs.environment || 'dev' }}
    
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

## Fehlerbehebung

### Häufige Probleme

1. **Authentifizierungsfehler**:

   - Überprüfe, ob der Environment-Name in GitHub exakt `azure-dev` ist
   - Stelle sicher, dass die OIDC-Berechtigungen aktiviert sind

2. **Berechtigungsfehler**:

   - Überprüfe, ob die RBAC-Rollen korrekt zugewiesen sind
   - Stelle sicher, dass die Managed Identity Zugriff auf die erforderlichen Ressourcen hat

3. **ACR-Zugriffsfehler**:
   - Überprüfe, ob die Managed Identity die Rolle "AcrPush" für die Container Registry hat

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
