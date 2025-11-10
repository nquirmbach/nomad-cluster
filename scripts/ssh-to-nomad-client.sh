#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP="rg-nomad-cluster-dev"
VMSS_NAME="nmdclstr-dev-client-vmss"
BASTION_NAME="nmdclstr-dev-bastion"
SSH_USER="azureuser"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Farben für die Ausgabe
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}SSH-Zugriff auf Nomad Client via Azure Bastion${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo -e "${YELLOW}1. Suche nach verfügbaren Nomad Client-Instanzen...${NC}"
echo ""

INSTANCES=$(az vmss list-instances \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VMSS_NAME" \
  --query "[].{InstanceId:instanceId, Name:name, ResourceId:id, PrivateIpAddress:privateIpAddress, State:instanceView.statuses[1].displayStatus}" \
  -o json)

if [ -z "$INSTANCES" ] || [ "$INSTANCES" == "[]" ]; then
  echo -e "${RED}❌ Keine VMSS-Instanzen gefunden!${NC}"
  exit 1
fi

# Anzahl der Instanzen
INSTANCE_COUNT=$(echo "$INSTANCES" | jq '. | length')

echo -e "${GREEN}$INSTANCE_COUNT Instanzen gefunden:${NC}"
echo ""

# Instanzen mit Nummerierung anzeigen
echo "$INSTANCES" | jq -r 'to_entries | .[] | "  [" + (.key | tostring) + "] Instance " + (.value.InstanceId) + ": " + (.value.Name) + " (" + (.value.State + ", IP: " + (.value.PrivateIpAddress // "unbekannt")) + ")"'
echo ""

# Interaktive Auswahl, wenn keine Instance ID angegeben wurde
if [ -n "${INSTANCE_ID:-}" ]; then
  echo -e "${YELLOW}Verwende angegebene Instance ID: $INSTANCE_ID${NC}"
  SELECTED_INDEX=$(echo "$INSTANCES" | jq -r "to_entries | .[] | select(.value.InstanceId==\"$INSTANCE_ID\") | .key")
  
  if [ -z "$SELECTED_INDEX" ] || [ "$SELECTED_INDEX" == "null" ]; then
    echo -e "${RED}❌ Keine Instanz mit ID $INSTANCE_ID gefunden!${NC}"
    exit 1
  fi
else
  # Benutzer nach Auswahl fragen
  echo -e "${YELLOW}Bitte wähle eine Instanz (0-$((INSTANCE_COUNT-1))):${NC}"
  read -r SELECTED_INDEX
  
  # Prüfen, ob die Eingabe gültig ist
  if ! [[ "$SELECTED_INDEX" =~ ^[0-9]+$ ]] || [ "$SELECTED_INDEX" -lt 0 ] || [ "$SELECTED_INDEX" -ge "$INSTANCE_COUNT" ]; then
    echo -e "${RED}❌ Ungültige Auswahl!${NC}"
    exit 1
  fi
fi

# Ausgewählte Instanz extrahieren
SELECTED_INSTANCE=$(echo "$INSTANCES" | jq -r ".[${SELECTED_INDEX}]")
INSTANCE_ID=$(echo "$SELECTED_INSTANCE" | jq -r '.InstanceId')
INSTANCE_NAME=$(echo "$SELECTED_INSTANCE" | jq -r '.Name')
RESOURCE_ID=$(echo "$SELECTED_INSTANCE" | jq -r '.ResourceId')
PRIVATE_IP=$(echo "$SELECTED_INSTANCE" | jq -r '.PrivateIpAddress // "unbekannt"')
STATE=$(echo "$SELECTED_INSTANCE" | jq -r '.State')

echo ""
echo -e "${GREEN}2. Verbinde zu Instance $INSTANCE_ID ($INSTANCE_NAME)...${NC}"
echo ""
echo -e "${BLUE}📋 Verbindungsdetails:${NC}"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   VMSS Name:      $VMSS_NAME"
echo "   Instance ID:    $INSTANCE_ID"
echo "   Instance Name:  $INSTANCE_NAME"
echo "   Private IP:     $PRIVATE_IP"
echo "   Status:         $STATE"
echo "   Bastion:        $BASTION_NAME"
echo "   User:           $SSH_USER"
echo "   SSH Key:        $SSH_KEY"
echo ""

echo -e "${YELLOW}🔐 Stelle SSH-Verbindung über Azure Bastion her...${NC}"
echo -e "${YELLOW}(Dies kann einen Moment dauern)${NC}"
echo ""

# Prüfe, ob der Bastion Host die richtige SKU und Native Client Support hat
BAST_INFO=$(az network bastion show --name "$BASTION_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null)
BAST_SKU=$(echo "$BAST_INFO" | jq -r '.sku.name // "Basic"')
NATIVE_CLIENT=$(echo "$BAST_INFO" | jq -r '.enableTunneling // false')

if [ "$BAST_SKU" == "Standard" ] && [ "$NATIVE_CLIENT" == "true" ]; then
  # Methode 1: Direkte SSH-Verbindung über Azure Bastion CLI
  echo -e "${GREEN}Verwende Azure Bastion CLI für SSH-Verbindung...${NC}"
  
  az network bastion ssh \
    --name "$BASTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --target-resource-id "$RESOURCE_ID" \
    --auth-type ssh-key \
    --username "$SSH_USER" \
    --ssh-key "$SSH_KEY"
    
  SSH_EXIT_CODE=$?
  
  if [ $SSH_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}Fehler bei der SSH-Verbindung über Azure Bastion CLI.${NC}"
    echo -e "${YELLOW}Versuche alternative Methode...${NC}"
    USE_ALTERNATIVE=true
  fi
else
  echo -e "${YELLOW}Azure Bastion Host hat nicht die erforderliche Konfiguration für CLI-Zugriff.${NC}"
  echo -e "${YELLOW}(Benötigt: SKU=Standard und Native Client Support aktiviert)${NC}"
  echo -e "${YELLOW}Verwende alternative Methode...${NC}"
  USE_ALTERNATIVE=true
fi

# Alternative Methode: Über Azure Portal
if [ "${USE_ALTERNATIVE:-false}" == "true" ]; then
  echo -e "${BLUE}=== Alternative Methode: SSH über Azure Portal ===${NC}"
  echo -e "${YELLOW}1. Öffne das Azure Portal: ${GREEN}https://portal.azure.com${NC}"
  echo -e "${YELLOW}2. Navigiere zu: ${GREEN}Virtual Machine Scale Sets > $VMSS_NAME${NC}"
  echo -e "${YELLOW}3. Wähle: ${GREEN}Instances > nmdclstr-dev-client-vmss_$INSTANCE_ID${NC}"
  echo -e "${YELLOW}4. Klicke auf: ${GREEN}Connect > Bastion${NC}"
  echo -e "${YELLOW}5. Gib folgende Daten ein:${NC}"
  echo -e "   ${GREEN}Username:${NC} $SSH_USER"
  echo -e "   ${GREEN}Authentication Type:${NC} SSH Private Key from Local File"
  echo -e "   ${GREEN}Local File:${NC} $SSH_KEY"
  echo -e "${YELLOW}6. Klicke auf ${GREEN}Connect${NC}"
  
  # Öffne das Azure Portal, wenn möglich
  if command -v open >/dev/null 2>&1; then
    echo -e "${YELLOW}Öffne Azure Portal...${NC}"
    open "https://portal.azure.com/#@/resource/subscriptions/*/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachineScaleSets/$VMSS_NAME/virtualMachines"
  elif command -v xdg-open >/dev/null 2>&1; then
    echo -e "${YELLOW}Öffne Azure Portal...${NC}"
    xdg-open "https://portal.azure.com/#@/resource/subscriptions/*/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachineScaleSets/$VMSS_NAME/virtualMachines"
  fi
fi
