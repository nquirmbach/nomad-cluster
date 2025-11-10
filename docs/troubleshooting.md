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

#### Methode 1: Admin-Credentials mit Client-Konfiguration (empfohlen für Demo/Dev)

1. Konfiguration:
   - Die ACR ist mit aktivierten Admin-Credentials konfiguriert
   - Die Credentials werden in der Nomad-Client-Konfiguration hinterlegt
   - Die Authentifizierung erfolgt automatisch auf Client-Ebene

2. Terraform-Konfiguration für ACR:
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

3. Nomad-Client-Konfiguration:
   ```hcl
   # Docker-Plugin-Konfiguration in client.hcl
   plugin "docker" {
     config {
       # ... andere Optionen ...
       
       # ACR-Authentifizierung auf Client-Ebene
       auth {
         config = "/etc/docker/config.json"
       }
     }
   }
   ```

4. Docker-Konfigurationsdatei (`/etc/docker/config.json`):
   ```json
   {
     "auths": {
       "acr-name.azurecr.io": {
         "auth": "BASE64_ENCODED_USERNAME_PASSWORD"
       }
     }
   }
   ```

5. Nomad-Job-Konfiguration:
   - Verwende eine einfache Docker-Konfiguration ohne Auth-Block:
   ```hcl
   config {
     image = "acr-name.azurecr.io/image:tag"
     ports = ["http"]
   }
   ```

6. Fehlersuche:
   - Überprüfe die Docker-Konfigurationsdatei:
   ```bash
   cat /etc/docker/config.json
   ```
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
   - Cloud-Init-Script wurde nicht korrekt ausgeführt
   - Nomad-Service wurde nicht aktiviert oder gestartet

3. Überprüfe, ob Nomad installiert ist:
   ```bash
   # Prüfe, ob die Nomad-Binärdatei existiert
   ls -la /usr/local/bin/nomad
   
   # Prüfe die Nomad-Version
   nomad version
   ```

4. Überprüfe die Cloud-Init-Logs:
   ```bash
   # Prüfe die Cloud-Init-Logs nach Nomad-bezogenen Einträgen
   sudo journalctl -u cloud-init | grep -i nomad
   
   # Prüfe die Cloud-Init-Ausgabe
   sudo cat /var/log/cloud-init-output.log
   
   # Prüfe das Setup-Log, falls vorhanden
   sudo cat /var/log/nomad-setup.log
   ```

5. Netzwerkverbindung prüfen:
   ```bash
   # Prüfe, ob die Clients die Server erreichen können
   nc -zv <server-ip> 4647
   
   # Prüfe die Netzwerkschnittstellen
   ip addr
   
   # Prüfe die Routing-Tabelle
   route -n
   ```

6. Nomad-Client-Konfiguration prüfen:
   ```bash
   # Prüfe, ob die Client-Konfiguration existiert
   ls -la /etc/nomad.d/
   
   # Prüfe die Client-Konfiguration
   cat /etc/nomad.d/client.hcl
   
   # Prüfe die Server-Adressen
   grep servers /etc/nomad.d/client.hcl
   ```

7. Nomad-Client-Dienst prüfen:
   ```bash
   # Prüfe, ob der Dienst existiert
   systemctl list-unit-files | grep nomad
   
   # Prüfe den Status des Nomad-Client-Dienstes
   systemctl status nomad-client
   
   # Aktiviere und starte den Dienst, falls nötig
   sudo systemctl enable nomad-client
   sudo systemctl start nomad-client
   
   # Prüfe die Logs
   journalctl -u nomad-client -n 100
   ```

8. Häufige Fehler im Cloud-Init-Script:
   - Falscher Benutzername: Wenn das Script versucht, den Benutzer `ubuntu` zur Docker-Gruppe hinzuzufügen, aber der Azure VM-Benutzer ist `azureuser`
   - Fehlende Berechtigungen: Stellen Sie sicher, dass die Verzeichnisse und Dateien die richtigen Berechtigungen haben
   - Fehlgeschlagene Downloads: Überprüfen Sie die Internetverbindung und die URL für den Nomad-Download

### Cloud-Init-Probleme bei der Nomad-Client-Installation

1. Problem:
   - Cloud-Init-Script wird nicht vollständig ausgeführt
   - Nomad wird nicht installiert oder gestartet
   - In den Cloud-Init-Logs fehlen Nomad-bezogene Einträge

2. Diagnose:
   ```bash
   # Prüfe den Status von Cloud-Init
   sudo cloud-init status
   
   # Prüfe die Cloud-Init-Logs
   sudo cat /var/log/cloud-init.log
   
   # Prüfe die Cloud-Init-Ausgabe
   sudo cat /var/log/cloud-init-output.log
   ```

3. Häufige Probleme und Lösungen:

   a) **Nomad-Benutzer wird nicht erstellt**:
   ```
   id: 'nomad': no such user
   chown: invalid user: 'nomad:nomad'
   ```
   
   Lösung:
   ```bash
   # Benutzer manuell erstellen
   sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad
   sudo mkdir -p /opt/nomad /etc/nomad.d
   sudo touch /var/log/nomad.log
   sudo chown -R nomad:nomad /opt/nomad /etc/nomad.d /var/log/nomad.log
   ```

   b) **Docker-Authentifizierung funktioniert nicht**:
   ```
   Login prior to pull:
   Log in with your Docker ID or email address to push and pull images from Docker Hub.
   ```
   
   Lösung:
   ```bash
   # Docker-Konfiguration manuell erstellen
   sudo mkdir -p /etc/docker /root/.docker /home/azureuser/.docker
   
   # Ersetze ACR_LOGIN_SERVER, ACR_USERNAME und ACR_PASSWORD mit den tatsächlichen Werten
   ENCODED_AUTH=$(echo -n "ACR_USERNAME:ACR_PASSWORD" | base64 -w0)
   
   # Erstelle die Konfigurationsdateien an allen relevanten Orten
   echo '{"auths":{"ACR_LOGIN_SERVER":{"auth":"'"$ENCODED_AUTH"'"}}}' | sudo tee /etc/docker/config.json
   echo '{"auths":{"ACR_LOGIN_SERVER":{"auth":"'"$ENCODED_AUTH"'"}}}' | sudo tee /root/.docker/config.json
   echo '{"auths":{"ACR_LOGIN_SERVER":{"auth":"'"$ENCODED_AUTH"'"}}}' | sudo tee /home/azureuser/.docker/config.json
   
   # Setze Berechtigungen
   sudo chmod 600 /etc/docker/config.json /root/.docker/config.json
   sudo chown azureuser:azureuser /home/azureuser/.docker/config.json
   sudo chmod 600 /home/azureuser/.docker/config.json
   
   # Neustart des Docker-Dienstes
   sudo systemctl restart docker
   ```

   c) **Nomad-Client-Service startet nicht**:
   
   Lösung:
   ```bash
   # Überprüfe die Nomad-Konfiguration
   sudo nomad validate /etc/nomad.d/client.hcl
   
   # Stelle sicher, dass die Verzeichnisse die richtigen Berechtigungen haben
   sudo mkdir -p /opt/nomad/data /etc/nomad.d
   sudo chown -R nomad:nomad /opt/nomad /etc/nomad.d /var/log/nomad.log
   sudo chmod 755 /opt/nomad /etc/nomad.d
   sudo chmod 644 /etc/nomad.d/client.hcl
   
   # Starte den Nomad-Client-Service neu
   sudo systemctl daemon-reload
   sudo systemctl restart nomad-client
   
   # Wenn der Service nicht startet, versuche einen manuellen Start
   sudo nohup /usr/local/bin/nomad agent -config=/etc/nomad.d > /var/log/nomad-manual.log 2>&1 &
   ```

4. Präventive Maßnahmen:
   - Füge ausführliche Logging in das Cloud-Init-Script ein
   - Verwende Fehlerbehandlung für kritische Befehle
   - Teste das Script in einer separaten VM, bevor es in der Produktion eingesetzt wird
   - Verwende `set -e` in Shell-Skripten, um bei Fehlern abzubrechen

### Docker-Treiber ist deaktiviert (disabled)

1. Problem:
   - Der Docker-Treiber wird in Nomad als "disabled" angezeigt
   - Jobs mit Docker-Tasks können nicht ausgeführt werden

2. Diagnose:
   ```bash
   # Überprüfe den Status des Docker-Treibers
   nomad node status -self -verbose | grep -A 10 "Docker Driver"
   
   # Überprüfe die Nomad-Client-Logs nach Docker-Fehlern
   sudo journalctl -u nomad-client | grep -i docker
   ```

3. Häufige Fehlermeldungen und Lösungen:

   a) **Berechtigungsproblem mit Docker-Socket**:
  ```
  "permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock"
  ```
  
  Empfohlene Lösungen (bevorzugte Reihenfolge):
  ```bash
  # Option 1 (empfohlen in diesem Setup): Nomad-Client als root laufen lassen
  # Prüfen:
  sed -n '/^\[Service\]/,/^\[Install\]/p' /etc/systemd/system/nomad-client.service
  # Erwartet: User=root, Group=root
  sudo systemctl daemon-reload && sudo systemctl restart nomad-client

  # Option 2: Nomad in die docker-Gruppe aufnehmen (wenn nicht als root)
  sudo usermod -aG docker nomad
  # Sicherstellen, dass Docker-Socket Gruppe=docker und Modus 660 hat
  sudo chgrp docker /var/run/docker.sock || true
  sudo chmod 660 /var/run/docker.sock || true
  sudo systemctl restart nomad-client
  ```
  Hinweis: `chmod 666 /var/run/docker.sock` sollte vermieden werden.

   b) **Nomad läuft nicht als Root**:
   ```
   "docker driver requires running as root: resources.cores and NUMA-aware scheduling will not function correctly"
   ```
   
   Lösung:
   ```bash
   # Bearbeite die Nomad-Client-Service-Datei
   sudo nano /etc/systemd/system/nomad-client.service
   
   # Ändere die Benutzer- und Gruppeneinstellungen
   # User=nomad
   # Group=nomad
   # zu
   # User=root
   # Group=root
   
   # Starte den Dienst neu
   sudo systemctl daemon-reload
   sudo systemctl restart nomad-client
   ```

   c) **Docker ist nicht installiert oder läuft nicht**:
   
   Lösung:
   ```bash
   # Überprüfe, ob Docker installiert ist
   which docker
   
   # Überprüfe den Docker-Dienststatus
   sudo systemctl status docker
   
   # Starte Docker, falls es nicht läuft
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

   d) **Falsche Docker-Plugin-Konfiguration in Nomad**:
   
   Lösung:
   ```bash
   # Überprüfe die Nomad-Client-Konfiguration
   cat /etc/nomad.d/client.hcl | grep -A 20 "plugin \"docker\""
   
   # Stelle sicher, dass der Docker-Plugin-Block korrekt ist
   # plugin "docker" {
   #   config {
   #     allow_privileged = true
   #     volumes {
   #       enabled = true
   #     }
   #   }
   # }
   ```

4. Nach der Behebung:
   ```bash
   # Starte den Nomad-Client neu
   sudo systemctl restart nomad-client
   
   # Überprüfe den Status des Docker-Treibers
   nomad node status -self -verbose | grep -A 10 "Docker Driver"
   ```

### Consul: "No cluster leader" Fehler

1. Problem:
   - Die Consul UI zeigt "Error: No cluster leader" an
   - Consul-Server können keinen Leader wählen
   - Nomad funktioniert möglicherweise trotzdem, da es einen eigenen Raft-Cluster hat

2. Häufige Ursachen:
   - Unterschiedliche Gossip-Verschlüsselungsschlüssel auf den Servern
   - `bootstrap_expect` ist höher als die tatsächliche Anzahl der Server
   - Server können sich nicht über die konfigurierten Adressen erreichen
   - Firewall blockiert Consul-Ports (8300, 8301, 8302, 8500, 8502)

3. Diagnose:
   ```bash
   # Überprüfe den Status der Consul-Mitglieder
   consul members
   
   # Überprüfe den Raft-Status
   consul operator raft list-peers
   
   # Überprüfe, ob ein Leader vorhanden ist
   curl -s localhost:8500/v1/status/leader
   
   # Überprüfe die Consul-Logs
   sudo journalctl -u consul -n 200 --no-pager
   ```

4. Lösungen:

   a) **Unterschiedliche Verschlüsselungsschlüssel**:
   
   Wenn in den Logs Fehler wie `handshake error` oder `error decrypting` erscheinen:
   
   ```bash
   # Generiere einen neuen Schlüssel
   consul keygen
   
   # Aktualisiere die Konfiguration auf allen Servern
   sudo nano /etc/consul.d/consul.hcl
   # Setze denselben Schlüssel für alle Server:
   # encrypt = "GEMEINSAMER_SCHLÜSSEL"
   
   # Starte Consul auf allen Servern neu
   sudo systemctl restart consul
   ```
   
   b) **Bootstrap-Erwartung anpassen**:
   
   ```bash
   # Überprüfe die aktuelle bootstrap_expect-Einstellung
   grep bootstrap_expect /etc/consul.d/consul.hcl
   
   # Passe sie an die tatsächliche Anzahl der Server an
   sudo nano /etc/consul.d/consul.hcl
   # bootstrap_expect = AKTUELLE_SERVER_ANZAHL
   
   # Starte Consul neu
   sudo systemctl restart consul
   ```
   
   c) **Netzwerkprobleme**:
   
   ```bash
   # Überprüfe die konfigurierten Join-Adressen
   grep retry_join /etc/consul.d/consul.hcl
   
   # Teste die Verbindung zu den anderen Servern
   nc -zv SERVER_IP 8301
   
   # Stelle sicher, dass bind_addr und retry_join im selben Netzwerk sind
   # bind_addr sollte die private IP sein
   # retry_join sollte die privaten IPs der anderen Server enthalten
   ```

5. Terraform-Konfiguration:
   
   Stelle sicher, dass in der Terraform-Konfiguration ein gemeinsamer Verschlüsselungsschlüssel verwendet wird:
   
   ```hcl
   # Generiere einen Schlüssel mit 'consul keygen'
   # Füge ihn als Variable hinzu
   variable "consul_encrypt" {
     description = "Consul Gossip Encryption Key"
     type        = string
     sensitive   = true
   }
   
   # Übergebe ihn an das Cloud-Init-Template
   custom_data = templatefile("...", {
     # ...
     consul_encrypt = var.consul_encrypt
     # ...
   })
   ```

6. Ansible-Konfiguration:
   
   ```yaml
   # Verwende eine Umgebungsvariable für den Schlüssel
   vars:
     consul_encrypt: "{{ lookup('env', 'CONSUL_ENCRYPT') }}"
   
   # Stelle sicher, dass der Schlüssel vorhanden ist
   - name: Ensure consul_encrypt is provided
     assert:
       that:
         - consul_encrypt is string
         - consul_encrypt | length > 0
   ```

## Nützliche Ressourcen

- [Nomad Dokumentation](https://www.nomadproject.io/docs)
- [Consul Dokumentation](https://www.consul.io/docs)
- [HashiCorp Learn](https://learn.hashicorp.com/nomad)
