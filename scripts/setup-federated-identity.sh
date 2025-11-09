#!/bin/bash
set -e

# Hilfe-Funktion
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Erstellt die notwendigen Azure-Ressourcen für Federated Identity mit GitHub Actions."
    echo ""
    echo "Options:"
    echo "  -e, --env ENV       Environment (dev, stg, prd), default: dev"
    echo "  -l, --location LOC  Azure Region, default: westeurope"
    echo "  -o, --org ORG       GitHub Organization/Username"
    echo "  -r, --repo REPO     GitHub Repository Name"
    echo "  -h, --help          Diese Hilfe anzeigen"
    echo ""
    echo "Beispiel: $0 --env prd --location germanywestcentral"
}

# Standardwerte
ENV="dev"
LOCATION="westeurope"
GITHUB_ORG="nquirmbach"  # Anpassen an deine GitHub Organisation/Username
GITHUB_REPO="nomad-cluster"  # Anpassen an dein Repository

# Parameter parsen
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -e|--env)
            ENV="$2"
            shift
            shift
            ;;
        -l|--location)
            LOCATION="$2"
            shift
            shift
            ;;
        -o|--org)
            GITHUB_ORG="$2"
            shift
            shift
            ;;
        -r|--repo)
            GITHUB_REPO="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unbekannte Option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validieren des Environments
case $ENV in
    dev|stg|prd)
        # Gültiges Environment
        ;;
    *)
        echo "Ungültiges Environment: $ENV. Erlaubte Werte: dev, stg, prd"
        exit 1
        ;;
esac

# Konfiguration mit String-Interpolation
PREFIX="nmdclstr-${ENV}"
RESOURCE_GROUP="rg-nomad-cluster-${ENV}"
ENVIRONMENT="${ENV}"
TERRAFORM_WORKSPACE="${ENV}"

# ACR-Name generieren (ohne Bindestriche)
ACR_NAME="${PREFIX//-/}acr"  # Name der Azure Container Registry

# Farben für die Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starte Setup der Federated Identity für GitHub Actions...${NC}"

# Prüfen, ob Azure CLI installiert ist
if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI ist nicht installiert. Bitte installiere es zuerst.${NC}"
    exit 1
fi

# Prüfen, ob GitHub CLI installiert ist
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI ist nicht installiert. GitHub Environment und Secrets müssen manuell erstellt werden.${NC}"
    GH_CLI_AVAILABLE=false
else
    GH_CLI_AVAILABLE=true
fi

# Prüfen, ob der Benutzer angemeldet ist
echo -e "${YELLOW}Prüfe Azure Login...${NC}"
ACCOUNT=$(az account show --query name -o tsv 2>/dev/null || echo "")
if [ -z "$ACCOUNT" ]; then
    echo -e "${YELLOW}Nicht angemeldet. Führe az login aus...${NC}"
    az login
fi

# Subscription ID abrufen
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}Verwende Subscription: $SUBSCRIPTION_ID${NC}"

# Tenant ID abrufen
TENANT_ID=$(az account show --query tenantId -o tsv)
echo -e "${GREEN}Verwende Tenant: $TENANT_ID${NC}"

# Resource Group erstellen, falls sie nicht existiert
echo -e "${YELLOW}Prüfe Resource Group...${NC}"
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${YELLOW}Resource Group existiert nicht. Erstelle...${NC}"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo -e "${GREEN}Resource Group erstellt.${NC}"
else
    echo -e "${GREEN}Resource Group existiert bereits.${NC}"
fi

# Hinweis: Azure Container Registry wird über Terraform erstellt
echo -e "${GREEN}Hinweis: Azure Container Registry wird über Terraform erstellt.${NC}"

# User-Assigned Managed Identity erstellen
echo -e "${YELLOW}Erstelle User-Assigned Managed Identity...${NC}"
IDENTITY_NAME="${PREFIX}-github-actions-identity"
IDENTITY_ID=$(az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
echo -e "${GREEN}Managed Identity erstellt: $IDENTITY_NAME${NC}"

# Principal ID und Client ID der Managed Identity abrufen
PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)
CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)
echo -e "${GREEN}Principal ID: $PRINCIPAL_ID${NC}"
echo -e "${GREEN}Client ID: $CLIENT_ID${NC}"

# Federated Identity Credential erstellen
echo -e "${YELLOW}Erstelle Federated Identity Credential...${NC}"
CREDENTIAL_NAME="${PREFIX}-github-actions-federated"
SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${ENVIRONMENT}"

echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}Subject: ${SUBJECT}${NC}"

# Prüfen, ob die Federated Identity Credential bereits existiert
CREDENTIAL_EXISTS=$(az identity federated-credential list --identity-name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='$CREDENTIAL_NAME'].name" -o tsv)
if [ -z "$CREDENTIAL_EXISTS" ]; then
    az identity federated-credential create \
        --name "$CREDENTIAL_NAME" \
        --identity-name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --audience "api://AzureADTokenExchange" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "$SUBJECT"
    echo -e "${GREEN}Federated Identity Credential erstellt.${NC}"
else
    echo -e "${GREEN}Federated Identity Credential existiert bereits.${NC}"
fi

# RBAC-Berechtigungen für Resource Group zuweisen
echo -e "${YELLOW}Weise RBAC-Berechtigungen für Resource Group zu...${NC}"
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)

# Contributor für Ressourcen-Erstellung
az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "Contributor" \
    --scope "$RG_ID" 2>/dev/null || echo -e "${YELLOW}Contributor-Zuweisung existiert bereits.${NC}"

# User Access Administrator für RBAC-Zuweisungen (z.B. ACR)
az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "User Access Administrator" \
    --scope "$RG_ID" 2>/dev/null || echo -e "${YELLOW}User Access Administrator-Zuweisung existiert bereits.${NC}"

echo -e "${GREEN}RBAC-Berechtigungen für Resource Group zugewiesen.${NC}"
echo -e "${GREEN}Die Managed Identity hat jetzt Contributor und User Access Administrator Rechte auf die Resource Group.${NC}"

# RBAC-Berechtigungen für Terraform Backend Storage Account zuweisen
echo -e "${YELLOW}Prüfe RBAC-Berechtigungen für Terraform Backend Storage Account...${NC}"
TF_STATE_SA="tfstatenomadcluster"
TF_STATE_RG="tf-state-rg"

if az storage account show --name "$TF_STATE_SA" --resource-group "$TF_STATE_RG" &>/dev/null; then
    SA_ID=$(az storage account show --name "$TF_STATE_SA" --resource-group "$TF_STATE_RG" --query id -o tsv)
    
    # Storage Blob Data Contributor für State-Zugriff
    az role assignment create \
        --assignee "$PRINCIPAL_ID" \
        --role "Storage Blob Data Contributor" \
        --scope "$SA_ID" 2>/dev/null || echo -e "${YELLOW}RBAC-Zuweisung existiert bereits.${NC}"
    
    echo -e "${GREEN}RBAC-Berechtigungen für Terraform Backend Storage Account zugewiesen.${NC}"
else
    echo -e "${YELLOW}Terraform Backend Storage Account existiert noch nicht.${NC}"
    echo -e "${YELLOW}Bitte erstelle ihn mit den Befehlen in den 'Nächsten Schritten'.${NC}"
    echo -e "${YELLOW}Danach führe dieses Script erneut aus, um die RBAC-Berechtigungen zu setzen.${NC}"
fi

echo -e "\n${GREEN}=== Setup abgeschlossen für Environment: $ENV ===${NC}"

# GitHub Environment und Secrets erstellen (falls GitHub CLI verfügbar)
if [ "$GH_CLI_AVAILABLE" = true ]; then
    echo -e "\n${YELLOW}Erstelle GitHub Environment und Secrets...${NC}"
    
    # Prüfen, ob gh authentifiziert ist
    if gh auth status &>/dev/null; then
        # Environment erstellen
        echo -e "${YELLOW}Erstelle GitHub Environment '$ENVIRONMENT'...${NC}"
        gh api repos/${GITHUB_ORG}/${GITHUB_REPO}/environments/${ENVIRONMENT} -X PUT 2>/dev/null || \
            echo -e "${YELLOW}Environment existiert bereits oder konnte nicht erstellt werden.${NC}"
        
        # Secrets erstellen
        echo -e "${YELLOW}Erstelle GitHub Secrets...${NC}"
        echo "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID --env $ENVIRONMENT --repo ${GITHUB_ORG}/${GITHUB_REPO}
        echo "$TENANT_ID" | gh secret set AZURE_TENANT_ID --env $ENVIRONMENT --repo ${GITHUB_ORG}/${GITHUB_REPO}
        echo "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID --env $ENVIRONMENT --repo ${GITHUB_ORG}/${GITHUB_REPO}
        
        echo -e "${GREEN}GitHub Environment und Secrets wurden erstellt!${NC}"
        echo -e "${YELLOW}Hinweis: OIDC muss manuell aktiviert werden (Settings → Actions → General → OpenID Connect)${NC}"
    else
        echo -e "${YELLOW}GitHub CLI ist nicht authentifiziert. Führe 'gh auth login' aus.${NC}"
        echo -e "${YELLOW}Secrets müssen manuell hinzugefügt werden.${NC}"
    fi
else
    echo -e "\n${GREEN}Bitte füge die folgenden Secrets zu deinem GitHub Repository hinzu:${NC}"
    echo -e "${YELLOW}AZURE_CLIENT_ID:${NC} $CLIENT_ID"
    echo -e "${YELLOW}AZURE_TENANT_ID:${NC} $TENANT_ID"
    echo -e "${YELLOW}AZURE_SUBSCRIPTION_ID:${NC} $SUBSCRIPTION_ID"
    echo -e "\n${GREEN}Wichtig: Stelle sicher, dass du in GitHub ein Environment '$ENVIRONMENT' erstellt hast.${NC}"
    echo -e "${GREEN}Aktiviere 'Allow GitHub Actions to request the OpenID Connect ID token' in den Repository-Einstellungen.${NC}"
fi
echo -e "\n${YELLOW}Verwendete Konfiguration:${NC}"
echo -e "${YELLOW}Environment:${NC} $ENV"
echo -e "${YELLOW}GitHub Environment:${NC} $ENVIRONMENT"
echo -e "${YELLOW}Terraform Workspace:${NC} $TERRAFORM_WORKSPACE"
echo -e "${YELLOW}Resource Group:${NC} $RESOURCE_GROUP"
echo -e "${YELLOW}Location:${NC} $LOCATION"
echo -e "${YELLOW}Prefix:${NC} $PREFIX"
echo -e "${YELLOW}ACR Name:${NC} $ACR_NAME"
