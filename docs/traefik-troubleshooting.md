# Traefik Troubleshooting

## Problembeschreibung

Traefik wird als Reverse Proxy im Nomad-Cluster eingesetzt, ist aber nicht über den Azure Load Balancer erreichbar.

## Bisherige Änderungen und Versuche

### 1. Ports geändert (9080/9081 → 8080/8081)

- **Problem**: Port-Konflikt mit anderen Diensten
- **Änderung**: Ports von 9080/9081 auf 8080/8081 geändert
- **Dateien**:
  - `jobs/traefik.nomad`
  - `terraform/modules/compute/main.tf`
  - `terraform/modules/network/main.tf`
- **Status**: Nicht erfolgreich

### 2. Health Probes angepasst

- **Problem**: HTTP Health Probes schlagen fehl
- **Änderung**: Von HTTP auf TCP Health Probes umgestellt
- **Dateien**: `terraform/modules/compute/main.tf`
- **Status**: Nicht erfolgreich

### 3. Traefik-Konfiguration umgestellt

- **Problem**: Traefik startet nicht korrekt
- **Änderung**: Von CLI-Argumenten auf TOML-Konfigurationsdatei umgestellt
- **Dateien**: `jobs/traefik.nomad`
- **Status**: Nicht erfolgreich

### 4. Consul-Integration

- **Problem**: Service-Discovery funktioniert nicht
- **Änderung**: Consul Catalog Provider aktiviert
- **Dateien**: `jobs/traefik.nomad`
- **Status**: Nicht erfolgreich

### 5. Network Mode

- **Problem**: Container-Netzwerk isoliert
- **Änderung**: `network_mode = "host"` hinzugefügt
- **Dateien**: `jobs/traefik.nomad`
- **Status**: Nicht erfolgreich

### 6. Traefik-Version

- **Problem**: Möglicherweise Inkompatibilität mit neuester Version
- **Änderung**: Von v2.10 auf v2.2 downgrade
- **Dateien**: `jobs/traefik.nomad`
- **Status**: Nicht erfolgreich

## Aktuelle Konfiguration

Die aktuelle Konfiguration basiert auf dem offiziellen HashiCorp-Tutorial:
https://developer.hashicorp.com/nomad/tutorials/load-balancing/load-balancing-traefik

- Traefik v2.2
- Host-Netzwerk-Modus
- TOML-Konfigurationsdatei
- Consul Catalog Provider
- Ports 8080 (HTTP) und 8081 (API/Dashboard)

## Nächste Schritte

1. **Überprüfen der Nomad-Client-Konfiguration**
   - Sicherstellen, dass Consul auf den Client-VMs läuft
   - Überprüfen, ob die Ports korrekt geöffnet sind

2. **Überprüfen der Azure Load Balancer Konfiguration**
   - Backend Pool überprüfen (Server vs. Client VMs)
   - Health Probe Einstellungen validieren

3. **Traefik-Logs analysieren**
   - Detaillierte Logs aktivieren
   - Nach spezifischen Fehlermeldungen suchen
