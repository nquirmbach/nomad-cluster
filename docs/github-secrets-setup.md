# GitHub Secrets Setup

Diese Dokumentation listet alle benötigten GitHub Secrets für die Workflows auf.

## Erforderliche Repository Secrets

### Azure Authentifizierung (für beide Workflows)

| Secret Name | Beschreibung | Wie zu erhalten |
|-------------|--------------|-----------------|
| `AZURE_CREDENTIALS` | Azure Service Principal Credentials im JSON-Format | Siehe [Azure Setup](#azure-credentials-erstellen) |

**Alternative mit Federated Identity (empfohlen):**

| Secret Name | Beschreibung | Wie zu erhalten |
|-------------|--------------|-----------------|
| `AZURE_CLIENT_ID` | Client ID der Managed Identity | `az identity show --name nomad-github-actions-identity --resource-group rg-nomad-cluster-dev --query clientId -o tsv` |
| `AZURE_TENANT_ID` | Azure Tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `az account show --query id -o tsv` |

### Terraform Backend (provision-cluster.yml)

| Secret Name | Beschreibung | Beispielwert |
|-------------|--------------|--------------|
| `TF_STATE_RG` | Resource Group für Terraform State | `rg-terraform-state` |
| `TF_STATE_SA` | Storage Account für Terraform State | `tfstatexxxxxx` (muss global eindeutig sein) |

**Einrichtung:**
```bash
# Resource Group erstellen
az group create --name rg-terraform-state --location westeurope

# Storage Account erstellen (Name muss global eindeutig sein)
STORAGE_ACCOUNT_NAME="tfstate$(openssl rand -hex 4)"
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group rg-terraform-state \
  --location westeurope \
  --sku Standard_LRS \
  --encryption-services blob

# Container erstellen
az storage container create \
  --name tfstate \
  --account-name $STORAGE_ACCOUNT_NAME

echo "TF_STATE_RG=rg-terraform-state"
echo "TF_STATE_SA=$STORAGE_ACCOUNT_NAME"
```

### Nomad Deployment (deploy-app.yml)

| Secret Name | Beschreibung | Wie zu erhalten |
|-------------|--------------|-----------------|
| `NOMAD_RESOURCE_GROUP` | Resource Group des Nomad Clusters | Nach Terraform Apply: `terraform output -raw resource_group_name` |
| `ACR_NAME` | Name der Azure Container Registry | Nach Terraform Apply: `terraform output -raw acr_login_server \| cut -d'.' -f1` |

**Hinweis:** 
- Diese Secrets werden erst nach dem ersten erfolgreichen Terraform-Deployment verfügbar
- Der Nomad Server wird automatisch aus der Resource Group ermittelt (kein NOMAD_SERVER_NAME Secret erforderlich)

## Azure Credentials erstellen

### Option 1: Service Principal (klassisch)

```bash
# Service Principal erstellen
az ad sp create-for-rbac \
  --name "nomad-github-actions" \
  --role contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv) \
  --sdk-auth

# Output als AZURE_CREDENTIALS Secret speichern
```

### Option 2: Federated Identity (empfohlen)

Siehe [github-azure-setup.md](./github-azure-setup.md) für detaillierte Anleitung.

## Secrets in GitHub hinzufügen

1. Navigiere zu deinem Repository auf GitHub
2. Gehe zu **Settings** > **Secrets and variables** > **Actions**
3. Klicke auf **New repository secret**
4. Füge jeden Secret mit dem entsprechenden Namen und Wert hinzu

## Environment-spezifische Secrets

Für das Environment `azure-dev`:

1. Gehe zu **Settings** > **Environments** > **azure-dev**
2. Unter "Environment secrets" können zusätzliche Secrets hinzugefügt werden
3. Diese überschreiben Repository Secrets mit gleichem Namen

## Secrets Validierung

Nach dem Hinzufügen der Secrets kannst du die Konfiguration testen:

```bash
# Workflow manuell triggern
gh workflow run provision-cluster.yml
```

## Troubleshooting

### "Secret not found" Fehler
- Überprüfe, ob der Secret-Name exakt übereinstimmt (case-sensitive)
- Stelle sicher, dass das Secret im richtigen Scope (Repository vs. Environment) definiert ist

### Azure Authentication Fehler
- Überprüfe, ob die Azure Credentials gültig sind
- Bei Federated Identity: Stelle sicher, dass das Environment `azure-dev` heißt

### Terraform Backend Fehler
- Überprüfe, ob Storage Account und Container existieren
- Stelle sicher, dass der Service Principal Zugriff auf den Storage Account hat

## Minimale Secrets für ersten Start

Für den ersten Terraform-Deployment benötigst du nur:

1. `AZURE_CREDENTIALS` (oder `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)
2. `TF_STATE_RG`
3. `TF_STATE_SA`

Nach erfolgreichem Deployment kannst du dann hinzufügen:
4. `NOMAD_RESOURCE_GROUP`
5. `ACR_NAME`
