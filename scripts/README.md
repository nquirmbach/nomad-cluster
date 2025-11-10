# SSH-Zugriff auf Nomad Clients

Dieses Verzeichnis enthält ein interaktives Script für den SSH-Zugriff auf Nomad Client-VMs über Azure Bastion.

## Voraussetzungen

- Azure CLI installiert und angemeldet (`az login`)
- `jq` installiert (für JSON-Verarbeitung)
- SSH-Schlüssel vorhanden (Standard: `~/.ssh/id_rsa`)

## Verwendung

### Interaktive Auswahl

Führe das Script ohne Parameter aus, um eine Liste aller verfügbaren Nomad Client-Instanzen zu sehen und interaktiv eine auszuwählen:

```bash
./ssh-to-nomad-client.sh
```

Das Script zeigt alle verfügbaren Instanzen mit Details an und fordert dich auf, eine Instanz auszuwählen:

```
2 Instanzen gefunden:

  [0] Instance 0: nmdclstr-dev-client-vmss_0 (VM running, IP: 10.0.10.7)
  [1] Instance 1: nmdclstr-dev-client-vmss_1 (VM running, IP: 10.0.10.8)

Bitte wähle eine Instanz (0-1):
```

Gib die Nummer der gewünschten Instanz ein und drücke Enter. Das Script stellt dann eine SSH-Verbindung über Azure Bastion her.

### Mit spezifischer Instance ID

Du kannst auch direkt eine bestimmte Instance ID angeben:

```bash
INSTANCE_ID=1 ./ssh-to-nomad-client.sh
```

### Mit benutzerdefiniertem SSH-Schlüssel

```bash
SSH_KEY=~/.ssh/mein_key ./ssh-to-nomad-client.sh
```

## Umgebungsvariablen

Das Script unterstützt folgende Umgebungsvariablen:

| Variable | Beschreibung | Standard |
|----------|--------------|----------|
| `INSTANCE_ID` | Spezifische VMSS-Instance ID | Interaktive Auswahl |
| `SSH_KEY` | Pfad zum privaten SSH-Schlüssel | `~/.ssh/id_rsa` |

## Funktionen

- Farbige Ausgabe für bessere Übersichtlichkeit
- Anzeige von Status und privater IP-Adresse jeder Instanz
- Interaktive Auswahl der Ziel-Instanz
- Unterstützung für benutzerdefinierte SSH-Schlüssel

## Troubleshooting

### "Bastion Host SKU must be Standard or Premium and Native Client must be enabled"

Dieser Fehler tritt auf, wenn der Azure Bastion Host nicht die richtige Konfiguration für CLI-Zugriff hat. Es gibt zwei Lösungen:

#### Lösung 1: Azure Bastion Host aktualisieren

Aktualisiere den Azure Bastion Host in der Terraform-Konfiguration:

```hcl
resource "azurerm_bastion_host" "nomad" {
  name                = "${var.prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"  # Standard SKU erforderlich für CLI-Zugriff
  
  # Native Client Support aktivieren
  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = true
  tunneling_enabled      = true
  ip_connect_enabled     = true
  
  # ...
}
```

Dann führe `terraform apply` aus, um die Änderungen anzuwenden.

#### Lösung 2: Alternative Methode verwenden

Das Script bietet automatisch eine alternative Methode an, die über das Azure Portal funktioniert. Folge einfach den Anweisungen im Script.

### "jq: command not found"

Installiere `jq`:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### "Azure CLI not found"

Installiere die Azure CLI:

```bash
# macOS
brew install azure-cli

# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### "The extension ssh is not installed"

Installiere die Azure CLI SSH-Erweiterung:

```bash
az extension add -n ssh
```

### "Authentication failed"

Stelle sicher, dass du bei Azure angemeldet bist:

```bash
az login
```

### SSH-Schlüssel nicht gefunden

Gib den Pfad zum SSH-Schlüssel explizit an:

```bash
SSH_KEY=/pfad/zu/deinem/key ./ssh-to-nomad-client.sh
```

## Weitere Informationen

Für weitere Informationen zur Verwendung von Azure Bastion siehe:
- [Azure Bastion Dokumentation](../docs/azure-bastion.md)
- [Azure Bastion CLI Referenz](https://learn.microsoft.com/en-us/cli/azure/network/bastion)
