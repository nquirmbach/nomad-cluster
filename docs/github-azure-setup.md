# GitHub und Azure Setup für Nomad Cluster

Diese Dokumentation beschreibt alle notwendigen Schritte, um die Azure-Umgebung und GitHub für die automatisierte Bereitstellung des Nomad Clusters einzurichten.

## Übersicht

Für die automatisierte Bereitstellung des Nomad Clusters mit GitHub Actions und Azure verwenden wir Federated Identity (OpenID Connect), um eine sichere Authentifizierung ohne gespeicherte Secrets zu ermöglichen.

![Federated Identity Architektur](https://learn.microsoft.com/de-de/azure/developer/github/media/github-actions/federated-identity-credential-flow.png)

## 1. Azure-Ressourcen einrichten

### Option A: Verwendung des Setup-Scripts

Das bereitgestellte Script erstellt automatisch alle erforderlichen Azure-Ressourcen:

```bash
# Script ausführbar machen
chmod +x scripts/setup-federated-identity.sh

# Script ausführen
./scripts/setup-federated-identity.sh
```

Das Script erstellt:
- Resource Group `rg-nomad-cluster-dev`
- Azure Container Registry
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

Nach der Einrichtung der Azure-Ressourcen müssen folgende Schritte im GitHub Repository durchgeführt werden:

### 2.1 Environment erstellen

1. Navigiere zu deinem Repository auf GitHub
2. Gehe zu **Settings** > **Environments**
3. Klicke auf **New environment**
4. Gib `azure-dev` als Namen ein
5. Optional: Konfiguriere Deployment Protection Rules (z.B. Required Reviewers)
6. Klicke auf **Configure environment**

### 2.2 Repository Secrets hinzufügen

1. Navigiere zu **Settings** > **Secrets and variables** > **Actions**
2. Füge folgende Repository Secrets hinzu:

   | Secret Name | Wert | Beschreibung |
   |-------------|------|-------------|
   | `AZURE_CLIENT_ID` | Client ID der Managed Identity | Ausgabe des Setup-Scripts oder `az identity show` |
   | `AZURE_TENANT_ID` | Tenant ID deines Azure-Kontos | Ausgabe von `az account show --query tenantId -o tsv` |
   | `AZURE_SUBSCRIPTION_ID` | Subscription ID | Ausgabe von `az account show --query id -o tsv` |
   | `NOMAD_RESOURCE_GROUP` | `rg-nomad-cluster-dev` | Name der Resource Group |
   | `ACR_NAME` | `nomadacr` | Name der Azure Container Registry |

### 2.3 Workflow-Berechtigungen aktivieren

1. Gehe zu **Settings** > **Actions** > **General**
2. Unter "Workflow permissions":
   - Aktiviere **Read and write permissions**
   - Aktiviere **Allow GitHub Actions to create and approve pull requests**
3. Unter "OpenID Connect":
   - Aktiviere **Allow GitHub Actions to request the OpenID Connect ID token**
4. Klicke auf **Save**

## 3. GitHub Actions Workflows

### 3.1 Cluster-Bereitstellung Workflow

Der Workflow `.github/workflows/provision-cluster.yml` verwendet die Federated Identity für die Authentifizierung bei Azure:

```yaml
name: Provision Nomad Cluster

on:
  workflow_dispatch:
  push:
    branches: [main]
    paths: ['terraform/**', 'ansible/**']

jobs:
  provision:
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
        description: 'Path to Nomad job file'
        required: true
        default: 'jobs/example.nomad'

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
