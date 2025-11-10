# Nomad Cluster Troubleshooting Guide

Dieses Dokument enthält nützliche Befehle und Anleitungen zur Fehlerbehebung im Nomad-Cluster.

## SSH-Verbindung zu Servern

```bash
# Verbindung zum ersten Server
task ssh SERVER=1

# Verbindung zum zweiten Server
task ssh SERVER=2

# Verbindung zum dritten Server
task ssh SERVER=3
```

## Nomad-Dienststatus prüfen

```bash
# Nomad-Dienststatus anzeigen
sudo systemctl status nomad

# Nomad-Logs anzeigen (live)
sudo journalctl -u nomad -f

# Nomad-Logs der letzten 100 Zeilen
sudo journalctl -u nomad -n 100

# Nomad-Logs seit dem letzten Boot
sudo journalctl -u nomad -b
```

## Nomad-Cluster-Status prüfen

```bash
# Nomad-Version anzeigen
nomad version

# Server-Status anzeigen
nomad server members

# Node-Status anzeigen
nomad node status

# Detaillierte Informationen zu einem Node
nomad node status -self
nomad node status <node-id>

# Raft-Peers anzeigen
nomad operator raft list-peers

# Cluster-Gesundheitsstatus
nomad operator debug
```

## Job-Management

```bash
# Alle Jobs anzeigen
nomad job status

# Detaillierte Informationen zu einem Job
nomad job status <job-id>

# Job validieren
nomad job validate <job-file>

# Job planen (Dry-Run)
nomad job plan <job-file>

# Job ausführen
nomad job run <job-file>

# Job stoppen
nomad job stop <job-id>
```

## Allokationen und Deployments

```bash
# Allokationen eines Jobs anzeigen
nomad job allocs <job-id>

# Detaillierte Informationen zu einer Allokation
nomad alloc status <alloc-id>

# Logs einer Allokation anzeigen
nomad alloc logs <alloc-id>

# Deployments anzeigen
nomad deployment list

# Deployment-Status anzeigen
nomad deployment status <deploy-id>
```

## Consul-Integration

```bash
# Consul-Status prüfen
consul members

# Consul-Dienststatus anzeigen
sudo systemctl status consul

# Consul-Logs anzeigen
sudo journalctl -u consul -f

# Consul-Dienste anzeigen
consul catalog services
```

## Konfigurationsprüfung

```bash
# Nomad-Konfiguration anzeigen
cat /etc/nomad.d/nomad.hcl

# Consul-Konfiguration anzeigen
cat /etc/consul.d/consul.hcl

# Konfiguration validieren
nomad agent -config=/etc/nomad.d -validate
```

## Häufige Probleme und Lösungen

### Nomad-Server startet nicht

1. Überprüfe die Logs:
   ```bash
   sudo journalctl -u nomad -f
   ```

2. Überprüfe die Konfiguration auf Syntaxfehler:
   ```bash
   nomad agent -config=/etc/nomad.d -validate
   ```

3. Häufige Probleme:
   - Falsche Syntax in der Konfigurationsdatei
   - Fehlende Berechtigungen für Datenverzeichnisse
   - Ports bereits in Verwendung

4. Lösung:
   - Korrigiere die Konfigurationsdatei
   - Setze die richtigen Berechtigungen: `sudo chown -R nomad:nomad /opt/nomad/data`
   - Überprüfe, ob die Ports frei sind: `sudo netstat -tulpn | grep <port>`

### Clients verbinden sich nicht mit Servern

1. Überprüfe die Client-Logs:
   ```bash
   sudo journalctl -u nomad -f
   ```

2. Überprüfe die Netzwerkverbindung:
   ```bash
   telnet <server-ip> 4647
   ```

3. Häufige Probleme:
   - Firewallregeln blockieren die Verbindung
   - Falsche Server-IPs in der Client-Konfiguration
   - TLS-Konfigurationsprobleme

4. Lösung:
   - Überprüfe die Firewallregeln
   - Überprüfe die Server-IPs in der Client-Konfiguration
   - Stelle sicher, dass die TLS-Zertifikate korrekt sind

### Jobs werden nicht geplant

1. Überprüfe den Job-Status:
   ```bash
   nomad job status <job-id>
   ```

2. Überprüfe die Evaluierungen:
   ```bash
   nomad eval list
   nomad eval status <eval-id>
   ```

3. Häufige Probleme:
   - Keine verfügbaren Ressourcen auf den Clients
   - Constraints können nicht erfüllt werden
   - Fehler in der Job-Definition

4. Lösung:
   - Überprüfe die verfügbaren Ressourcen: `nomad node status`
   - Überprüfe die Job-Constraints
   - Validiere die Job-Definition: `nomad job validate <job-file>`

### Nomad Job Plan gibt Exit-Code 1 zurück

1. Problem:
   - Der Befehl `nomad job plan` gibt Exit-Code 1 zurück, wenn Änderungen erkannt werden
   - Dies ist erwartetes Verhalten, wird aber in CI/CD-Pipelines oft als Fehler interpretiert

2. Lösung für GitHub Actions:
   ```yaml
   - name: Plan Job
     continue-on-error: true
     run: nomad job plan -var="IMAGE_VERSION=$VERSION" job.nomad
   ```

3. Lösung für andere CI/CD-Systeme:
   - Verwende bedingte Logik, um Exit-Code 1 als erfolgreich zu behandeln
   - Oder verwende `|| true` am Ende des Befehls, um Fehler zu ignorieren

### ACR-Authentifizierung

#### Methode 1: Admin-Credentials (empfohlen für Demo/Dev)

1. Konfiguration:
   - Die ACR ist mit aktivierten Admin-Credentials konfiguriert
   - Die Credentials werden automatisch beim Hochfahren der Clients verwendet
   - Die Clients führen `docker login` mit den Admin-Credentials aus

2. Terraform-Konfiguration:
   ```hcl
   resource "azurerm_container_registry" "acr" {
     name                = replace("${var.prefix}acr", "-", "")
     resource_group_name = var.resource_group_name
     location            = var.location
     sku                 = "Standard"
     admin_enabled       = true
     tags                = var.tags
   }
   ```

3. Nomad-Job-Konfiguration:
   - Verwende eine einfache Docker-Konfiguration ohne Auth-Block:
   ```hcl
   config {
     image = "acr-name.azurecr.io/image:tag"
     ports = ["http"]
   }
   ```

4. Fehlersuche:
   - Überprüfe, ob Docker erfolgreich eingeloggt ist:
   ```bash
   docker info | grep -A 5 "Registry"
   ```
   - Teste manuell das Pullen eines Images:
   ```bash
   docker pull <acr-name>.azurecr.io/<image>:<tag>
   ```

#### Methode 2: Managed Identity (für Produktion)

1. Problem:
   - Fehler: `Driver Failure: Failed to find docker auth for repo "acr-name.azurecr.io/image": exec: "docker-credential-acr-env": executable file not found in $PATH`
   - Dies bedeutet, dass die Authentifizierung mit Azure Container Registry nicht korrekt eingerichtet ist

2. Lösung mit Azure CLI:
   - Installiere die Azure CLI auf den Nomad-Client-Nodes:
   ```bash
   # Installiere die Azure CLI
   curl -sL https://aka.ms/InstallAzureCLIDeb | bash
   
   # Konfiguriere die VM-Managed-Identity für ACR
   az login --identity
   
   # Teste die ACR-Authentifizierung
   az acr login --name <acr-name>
   ```

3. Terraform-Konfiguration:
   - Stelle sicher, dass die RBAC-Rolle für ACR Pull korrekt zugewiesen ist:
   ```hcl
   resource "azurerm_role_assignment" "nomad_client_acr_pull" {
     scope                = var.acr_id
     role_definition_name = "AcrPull"
     principal_id         = azurerm_linux_virtual_machine_scale_set.nomad_client.identity[0].principal_id
   }
   ```

### Nomad-Clients erscheinen nicht im Dashboard

1. Problem:
   - Nomad-Clients erscheinen nicht im Dashboard
   - Server und Clients können sich nicht verbinden

2. Mögliche Ursachen:
   - Netzwerkprobleme zwischen Clients und Servern
   - Falsche Server-Adressen in der Client-Konfiguration
   - Firewall blockiert die Verbindung
   - Fehlerhafte Nomad-Konfiguration

3. Netzwerkverbindung prüfen:
   ```bash
   # Prüfe, ob die Clients die Server erreichen können
   nc -zv <server-ip> 4647
   
   # Prüfe die Netzwerkschnittstellen
   ip addr
   
   # Prüfe die Routing-Tabelle
   route -n
   ```

4. Nomad-Client-Konfiguration prüfen:
   ```bash
   # Prüfe die Client-Konfiguration
   cat /etc/nomad.d/client.hcl
   
   # Prüfe die Server-Adressen
   grep servers /etc/nomad.d/client.hcl
   ```

5. Nomad-Client-Dienst prüfen:
   ```bash
   # Prüfe den Status des Nomad-Client-Dienstes
   systemctl status nomad-client
   
   # Prüfe die Logs
   journalctl -u nomad-client -n 100
   ```

6. Firewall-Regeln prüfen:
   ```bash
   # Prüfe die Firewall-Regeln
   sudo iptables -L
   
   # Prüfe die Sicherheitsgruppen in Azure
   ```

7. Debug-Skript ausführen:
   ```bash
   # Führe das Debug-Skript aus
   /opt/scripts/debug-nomad.sh > /tmp/nomad-debug.log
   
   # Analysiere die Ausgabe
   cat /tmp/nomad-debug.log
   ```

## Nützliche Ressourcen

- [Nomad Dokumentation](https://www.nomadproject.io/docs)
- [Consul Dokumentation](https://www.consul.io/docs)
- [HashiCorp Learn](https://learn.hashicorp.com/nomad)
