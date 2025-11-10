# Nomad vs. Kubernetes - Evaluierung als Alternative für Enterprise-Orchestrierung

> **Präsentation für interne Berater-Runde**  
> Dauer: 30 Minuten  
> Ziel: Evaluierung von Nomad als Alternative zu Kubernetes

---

## Executive Summary

Diese Präsentation evaluiert HashiCorp Nomad als potenzielle Alternative zu Kubernetes für Container- und Workload-Orchestrierung.

**Kernfragen:**

- Ist Nomad eine realisierbare Alternative zu Kubernetes?
- Für welche Kundenprojekte macht Nomad Sinn?
- Sollten wir Nomad in unser Beratungsportfolio aufnehmen?

**Fokus:** Kosten, Governance, Marktrelevanz, Technische Machbarkeit

---

## Agenda (30 Min)

| Zeit      | Thema                   | Details                               |
| --------- | ----------------------- | ------------------------------------- |
| 0-5 Min   | Einführung in Nomad     | Was ist Nomad? Kernkonzepte           |
| 5-15 Min  | Live-Demo               | Azure-Setup, Deployment, Skalierung   |
| 15-25 Min | Evaluierung & Vergleich | Tech-Stack, Markt, Kosten, Governance |
| 25-30 Min | Fazit & Q&A             | Empfehlungen, Diskussion              |

---

# Teil 1: Einführung in HashiCorp Nomad (5 Min)

## Was ist Nomad?

HashiCorp Nomad ist ein **flexibler Workload-Orchestrator**, der die Bereitstellung und Verwaltung von Anwendungen über verschiedene Infrastrukturen hinweg vereinfacht.

### Kernmerkmale

- **Single Binary**: Eine ausführbare Datei für Server und Client (~100 MB)
- **Multi-Workload**: Unterstützt Docker, VMs, Java, .NET, Binary
- **Cloud-Agnostic**: Läuft auf AWS, Azure, GCP, On-Premise
- **Einfache Architektur**: Flache Lernkurve im Vergleich zu K8s

### Architektur-Überblick

```
┌────────────────────────────────────────────┐
│           Nomad Architecture                │
├────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────┐      │
│  │     Nomad Server Cluster         │      │
│  │  (Raft Consensus, 3-5 Nodes)     │      │
│  │                                   │      │
│  │  • Job Scheduling                 │      │
│  │  • State Management               │      │
│  │  • Service Discovery              │      │
│  └───────────┬──────────────────────┘      │
│              │                              │
│  ┌───────────▼──────────────────────┐      │
│  │    Nomad Client Nodes             │      │
│  │    (Worker Nodes)                 │      │
│  │                                   │      │
│  │  • Run Workloads                  │      │
│  │  • Report Status                  │      │
│  │  • Auto-Scaling                   │      │
│  └───────────────────────────────────┘      │
│                                             │
└────────────────────────────────────────────┘
```

### Nomad vs. Kubernetes - Erste Unterschiede

| Aspekt             | Nomad                         | Kubernetes          |
| ------------------ | ----------------------------- | ------------------- |
| **Binärgröße**     | ~100 MB                       | >1 GB               |
| **Komponenten**    | 1 Binary                      | 10+ Komponenten     |
| **Lernkurve**      | Flach (~1 Woche)              | Steil (~3-6 Monate) |
| **Workload-Typen** | Multi (Docker, VMs, Binaries) | Primär Container    |
| **Setup-Zeit**     | Minuten                       | Stunden/Tage        |

### Konzept-Mapping: Kubernetes → Nomad

**Für K8s-Praktiker: So übersetzt man Konzepte**

| Kubernetes     | Nomad                        | Beschreibung                           |
| -------------- | ---------------------------- | -------------------------------------- |
| **Pod**        | **Task Group**               | Gruppe von zusammengehörigen Workloads |
| **Container**  | **Task**                     | Einzelne ausführbare Einheit           |
| **Deployment** | **Job**                      | Deklarative Workload-Definition        |
| **ReplicaSet** | **Task Group (count)**       | Anzahl der Instanzen                   |
| **Service**    | **Service (Consul)**         | Service Discovery & DNS                |
| **Ingress**    | **Ingress Gateway (Consul)** | Externes Routing                       |
| **ConfigMap**  | **Template Stanza**          | Konfiguration                          |
| **Secret**     | **Vault Integration**        | Secrets Management                     |
| **DaemonSet**  | **Job (type=system)**        | Pro-Node-Deployment                    |
| **Job**        | **Job (type=batch)**         | Einmalige Tasks                        |
| **Namespace**  | **Namespace**                | Logische Trennung                      |

**Wichtig:** Nomad ist **flacher** - weniger Abstraktionsebenen als K8s!

---

# Teil 2: Live-Demo (10 Min)

## Demo-Setup: Nomad Cluster auf Azure

**Was gezeigt wird:**

1. ✅ Cluster-Architektur in Azure
2. ✅ Job-Deployment (Web-Anwendung)
3. ✅ Service Discovery & Networking
4. ✅ Auto-Scaling & Self-Healing
5. ✅ Monitoring & Observability

### Demo-Architektur

```
Azure Cloud (West Europe)
├── Virtual Network (10.0.0.0/16)
│   ├── Server Subnet (3x Nomad Server)
│   │   └── Standard_D2s_v5 VMs
│   ├── Client Subnet (Auto-Scaling)
│   │   └── VMSS (3-10 Nodes)
│   └── Internal Load Balancer
├── Azure Key Vault (Secrets)
├── Log Analytics (Monitoring)
└── GitHub Actions (CI/CD)
```

**Infrastruktur-Komponenten:**

- **3x Nomad Server**: Hochverfügbarer Cluster (Raft Consensus)
- **3-10x Client Nodes**: Auto-Scaling basierend auf Last
- **Consul**: Service Discovery & Health Checks
- **Azure Load Balancer**: Interner Traffic-Routing

### Demo-Ablauf

#### 1. Cluster-Status anzeigen

```bash
# Nomad Server Status
nomad server members

# Client Nodes anzeigen
nomad node status

# System-Übersicht
nomad status
```

**Erwartetes Ergebnis:**

- 3 Server im Quorum
- N Client-Nodes (healthy)
- Cluster-Verfügbarkeit 100%

#### 2. Job deployen (Web-Anwendung)

**Job-Definition:** `web.nomad`

```hcl
job "web-app" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        to = 5000
      }
    }

    task "flask-app" {
      driver = "docker"

      config {
        image = "ghcr.io/[...]/web-app:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
```

**Deployment:**

```bash
nomad job run jobs/web.nomad
nomad job status web-app
```

#### 3. Skalierung demonstrieren

```bash
# Horizontal skalieren
nomad job scale web-app web 5

# Auto-Scaling (VMSS)
# - Azure VMSS skaliert bei >70% CPU
# - Nomad verteilt Jobs automatisch
```

#### 4. Self-Healing zeigen

```bash
# Allokation stoppen (simulierter Ausfall)
nomad alloc stop <alloc-id>

# Nomad startet automatisch neu
nomad job status web-app
```

### Demo-Highlights

**Für technische Berater:**

- Einfache Job-Definition (HCL-Syntax)
- Schnelles Deployment (Sekunden)
- Transparente Scheduling-Entscheidungen

**Für nicht-technische Berater:**

- Web-UI (Nomad Dashboard)
- Klare Status-Visualisierung
- Einfache Konzepte

---

# Teil 3: Evaluierung - Nomad vs. Kubernetes (10 Min)

## 1. Technischer Vergleich

### Architektur-Komplexität

| Komponente            | Nomad       | Kubernetes         |
| --------------------- | ----------- | ------------------ |
| **Control Plane**     | 1 Binary    | 4+ Komponenten     |
| **Data Plane**        | 1 Binary    | 2+ Komponenten     |
| **Service Discovery** | Integriert  | Externe Lösung     |
| **Storage**           | Basic (CSI) | Erweitert (PV/PVC) |
| **Networking**        | Einfach     | Komplex (CNI)      |

### Feature-Vergleich

| Feature                      | Nomad          | Kubernetes         | Bewertung           |
| ---------------------------- | -------------- | ------------------ | ------------------- |
| **Container-Orchestrierung** | ✅ Sehr gut    | ✅ Exzellent       | K8s leicht vorne    |
| **Multi-Workload**           | ✅ Native      | ⚠️ Mit Plugins     | Nomad überlegen     |
| **Service Mesh**             | ⚠️ Via Consul  | ✅ Istio, Linkerd  | K8s reifer          |
| **Auto-Scaling**             | ✅ Job & Node  | ✅ HPA/VPA/CA      | Vergleichbar        |
| **Secrets Management**       | ⚠️ Basic/Vault | ✅ Native          | K8s besser          |
| **GitOps**                   | ⚠️ Limitiert   | ✅ ArgoCD/Flux     | K8s ausgereifter    |
| **Observability**            | ⚠️ Basis       | ✅ Umfangreich     | K8s deutlich besser |
| **Multi-Tenancy**            | ⚠️ Namespaces  | ✅ Namespaces+RBAC | K8s besser          |

### Erweiterbarkeit & CRDs

**Custom Resource Definitions (CRDs) - Kubernetes Killer-Feature:**

Kubernetes erlaubt es, eigene APIs und Ressourcentypen zu definieren:

```yaml
# Beispiel: Custom Resource
apiVersion: apps.example.com/v1
kind: Database
metadata:
  name: my-postgres
spec:
  version: "14"
  storage: 100Gi
  replicas: 3
```

**Kubernetes CRDs:**

- ✅ Native API-Erweiterung
- ✅ Eigene Controller (Operator Pattern)
- ✅ Deklarative Custom Resources
- ✅ Versionierung & Validation
- ✅ Riesiges Ecosystem (100+ Operators)

**Beispiel-Operators:**

- Prometheus Operator (Monitoring)
- Cert-Manager (TLS-Zertifikate)
- Postgres Operator (Datenbanken)
- Istio Operator (Service Mesh)
- Argo CD (GitOps)

**Nomad-Äquivalent:**

- ❌ Keine CRDs oder vergleichbare Erweiterbarkeit
- ⚠️ Job-Templates mit Variablen (limitiert)
- ⚠️ Plugins für Task-Treiber (komplexer)
- ⚠️ Nomad Pack (Template-System, Alpha-Stadium)

**Impact:**

- K8s-Ecosystem baut massiv auf CRDs auf
- Nomad fehlt diese Erweiterbarkeit → Geringeres Ecosystem
- **Für Enterprises**: CRDs ermöglichen standardisierte Plattformen

### Was Nomad besser macht als Kubernetes

**Nomads Design-Philosophie: "Einfachheit über Features"**

#### 1. Multi-Workload Support (Native)

**Problem bei Kubernetes:**

- Primär für Container designed
- VMs benötigen KubeVirt (komplex)
- Binaries benötigen Workarounds
- Java-Apps ohne Container aufwändig

**Nomad-Lösung:**

```hcl
# Docker-Container
task "web" {
  driver = "docker"
  config { image = "nginx" }
}

# Java-Anwendung (kein Container)
task "batch" {
  driver = "java"
  config { jar_path = "app.jar" }
}

# VM (über QEMU)
task "legacy" {
  driver = "qemu"
  config { image_path = "vm.qcow2" }
}

# Binary direkt
task "script" {
  driver = "exec"
  config { command = "/usr/bin/python3" }
}
```

**Vorteil:** Legacy-Modernisierung ohne vollständige Containerisierung

#### 2. Operationale Einfachheit

**Problem bei Kubernetes:**

- Komplexes Troubleshooting (etcd, API-Server, Scheduler, Controller)
- Upgrade-Komplexität (K8s Minor-Versions alle 3 Monate)
- Viele bewegliche Teile

**Nomad-Lösung:**

- Single Binary → Einfaches Troubleshooting
- Weniger Breaking Changes
- Upgrades: Binary austauschen, neu starten

**Beispiel - Debugging:**

```bash
# Nomad: Ein Prozess zum Debuggen
ps aux | grep nomad
tail -f /var/log/nomad.log

# Kubernetes: Mehrere Komponenten
kubectl logs -n kube-system kube-apiserver-...
kubectl logs -n kube-system kube-scheduler-...
kubectl logs -n kube-system kube-controller-manager-...
journalctl -u kubelet
# + etcd separat debuggen
```

#### 3. Ressourcen-Effizienz

**Control Plane Ressourcen:**

| Setup        | Nomad            | Kubernetes         |
| ------------ | ---------------- | ------------------ |
| **CPU**      | ~200m pro Server | ~2000m (2 Cores)   |
| **Memory**   | ~512 MB          | ~4 GB              |
| **Disk I/O** | Niedrig          | Mittel-Hoch (etcd) |

**Für Edge/IoT**: Nomad läuft auf deutlich kleineren Maschinen

#### 4. Schnelleres Job-Scheduling

**Scheduling Performance:**

- Nomad: ~1000 Placements/Sekunde
- Kubernetes: ~100-300 Pods/Sekunde

**Use Case:** Batch-Processing, Data-Pipelines, kurzlebige Jobs

#### 5. Flexible Datacenter-Federation

**Nomad WAN Federation:**

- Native Multi-Region ohne zusätzliche Tools
- Jobs über Regionen hinweg orchestrieren
- Einfachere Topologie als K8s-Federation

**Kubernetes:**

- Benötigt zusätzliche Tools (Rancher, Submariner)
- Komplexe Netzwerk-Konfiguration
- Höherer Betriebs-Overhead

### Was Kubernetes deutlich besser macht

#### 1. Deklaratives Modell & Reconciliation

**Kubernetes Operator Pattern:**

- Kontinuierliche Reconciliation Loop
- Automatische Drift-Korrektur
- Self-Healing über Desired State

**Nomad:**

- Teilweise deklarativ
- Weniger ausgereift bei komplexen State-Übergängen

#### 2. Networking & Service Mesh

**Kubernetes:**

- Ausgereiftes CNI-Ecosystem (Calico, Cilium, etc.)
- Native Network Policies
- Service Mesh Integration (Istio, Linkerd)
- Ingress Controller Ecosystem

**Nomad:**

- Basis-Networking (Bridge, Host)
- Consul Connect für Service Mesh (zusätzliche Komponente)
- Weniger Feature-reich

#### 3. Storage Orchestration

**Kubernetes:**

- StorageClasses für dynamische Provisioning
- Volume Snapshots
- CSI-Treiber-Ecosystem
- StatefulSets mit ordered deployment

**Nomad:**

- Host Volumes (statisch)
- CSI-Support (begrenzt)
- Keine native Snapshot-Funktionalität

#### 4. Observability-Integration

**Kubernetes Vorteile:**

```
Native Integration:
├── Prometheus (Metrics)
├── Fluentd/Loki (Logs)
├── Jaeger (Tracing)
├── OpenTelemetry
└── Service Mesh Telemetry
```

**Nomad:**

- Prometheus-Integration (manuell)
- Logging per Syslog
- Tracing: externe Integration notwendig

#### 5. Platform Engineering

**Kubernetes als Plattform:**

- CRDs für Abstraktion (Developer Self-Service)
- Operator Framework für Custom Automation
- Backstage/Port für Internal Developer Platforms

**Nomad:**

- Limitierte Abstraktion-Möglichkeiten
- Kein etabliertes Platform-Engineering-Ecosystem

### Community & Ecosystem-Vergleich

#### Kubernetes Community

**Zahlen (2024):**

- **Contributors**: >3000 aktive
- **GitHub Stars**: >110.000
- **Meetups**: Global >500, DACH >50
- **Konferenzen**: KubeCon (10.000+ Attendees)
- **CNCF Projects**: 150+ integrierte Tools
- **Stack Overflow**: >100.000 Fragen

**Community-Aktivität:**

- Täglich neue Releases/Tools
- Aktive Special Interest Groups (SIGs)
- Vendor-neutral (CNCF)

#### Nomad Community

**Zahlen (2024):**

- **Contributors**: ~200 aktive
- **GitHub Stars**: ~14.000
- **Meetups**: Global <20, DACH ~2
- **Konferenzen**: HashiConf (Nomad = Teilbereich)
- **Ecosystem**: ~20-30 Plugins/Tools
- **Stack Overflow**: ~1.500 Fragen

**Community-Aktivität:**

- Weniger frequent Releases
- Primär HashiCorp-getrieben
- Kleinere aber fokussierte Community

#### Ecosystem-Größe

**CNCF Landscape (K8s-relevant): ~1.000 Tools**

Kategorien:

- Container Registries: 20+
- CI/CD: 50+
- Monitoring: 40+
- Security: 80+
- Service Mesh: 10+
- Storage: 30+

**Nomad Ecosystem: ~30 Tools**

- Task Drivers: 10
- Deployment Tools: 5
- Monitoring Plugins: 5
- CI/CD Integration: Wenige

**Impact:**

- K8s: Lösung für fast jedes Problem verfügbar
- Nomad: Oft Custom-Entwicklung notwendig

### Limitations beider Systeme

#### Kubernetes Limitations

**1. Komplexität**

- Steile Lernkurve (3-6 Monate bis produktiv)
- Schwieriges Troubleshooting
- Upgrade-Risiken bei Breaking Changes

**2. Ressourcen-Overhead**

- Control Plane benötigt signifikante Ressourcen
- etcd als Single Point of Complexity
- Nicht geeignet für Edge/IoT (<2GB RAM)

**3. Über-Engineering für kleine Teams**

- Zu viele Features für einfache Use Cases
- Overhead ohne entsprechenden Nutzen bei <5 Services

**4. Multi-Tenancy Herausforderungen**

- "Harte" Multi-Tenancy schwierig
- Namespace-Isolation nicht vollständig
- Shared Control Plane Risiken

**5. Stateful Workloads**

- StatefulSets komplex
- Backup/Restore nicht trivial
- Storage-Orchestration fehleranfällig

#### Nomad Limitations

**1. Feature-Gaps**

- Kein natives Secrets-Management (Vault benötigt)
- Eingeschränkte Network Policies
- Kein Ingress-Controller-Konzept

**2. Ecosystem-Limitierung**

- Wenige Third-Party-Tools
- Kaum fertige Lösungen (Operators, etc.)
- Mehr Custom-Development notwendig

**3. Erweiterbarkeit**

- Keine CRDs oder ähnliches
- Schwierig, eigene Abstraktionen zu bauen
- Limitiertes Plugin-System

**4. Enterprise-Features**

- Viele Features nur in Enterprise-Version
- Audit-Logging nicht in OSS
- SSO-Integration Enterprise-only

**5. Markt-Position**

- Schwierige Rekrutierung
- Weniger Training-Material
- Geringere Vendor-Unterstützung

**6. GitOps-Maturity**

- Kein ArgoCD/Flux-Äquivalent
- Levant/Nomad Pack noch unreif
- Mehr manuelle Prozesse

**7. Observability**

- Keine native Metrics-Aggregation
- Logging basic
- Distributed Tracing extern

#### Vergleich: Welche Limitation wiegt schwerer?

| Limitation                   | Nomad | Kubernetes | Kritikalität      |
| ---------------------------- | ----- | ---------- | ----------------- |
| **Lernkurve**                | ✅    | ❌         | Hoch (Onboarding) |
| **Ressourcen-Overhead**      | ✅    | ❌         | Mittel (Kosten)   |
| **Feature-Vollständigkeit**  | ❌    | ✅         | Hoch (Enterprise) |
| **Ecosystem**                | ❌    | ✅         | Sehr Hoch         |
| **Community-Support**        | ❌    | ✅         | Hoch              |
| **Erweiterbarkeit**          | ❌    | ✅         | Sehr Hoch         |
| **Multi-Workload**           | ✅    | ❌         | Mittel (Nische)   |
| **Operationale Einfachheit** | ✅    | ❌         | Mittel            |

**Fazit Limitations:**

- K8s-Limitations betreffen primär **Einstieg und Betrieb**
- Nomad-Limitations betreffen **Features und Zukunftssicherheit**
- Für Enterprises wiegen Nomad-Limitations schwerer

### Praktiker-Erfahrungen: Der Umstieg von K8s zu Nomad

**Quelle:** Iris Carrera (SRE bei HashiCorp) - "Nomad for Kubernetes Practitioners"

#### Was einfacher ist bei Nomad

✅ **Schnellerer Einstieg**

- Dev-Cluster in Sekunden: `nomad agent -dev`
- Keine komplexe Cluster-Initialisierung
- Sofort produktiv ohne tagelange Einarbeitung

✅ **Weniger Abstraktionsschichten**

- Kein Helm, Kustomize, Operators notwendig
- Direkte Job-Definitionen in HCL
- Klare 1:1-Beziehung zwischen Code und Deployment

✅ **Einfacheres Mental Model**

- Job → Task Group → Task (3 Ebenen)
- vs. K8s: Deployment → ReplicaSet → Pod → Container (4+ Ebenen)

#### Was herausfordernd ist

⚠️ **Mindset-Wechsel erforderlich**

- Weniger "Magie" als bei K8s
- Mehr explizite Konfiguration
- Andere Denkweise bei Service Discovery (Consul vs. K8s Services)

⚠️ **Fehlende Tooling-Reife**

- Kein Helm-Äquivalent (Nomad Pack ist Alpha)
- Weniger fertige Lösungen
- Mehr manuelle Arbeit bei komplexen Deployments

⚠️ **Dokumentation & Community**

- Weniger Stack Overflow-Antworten
- Kleinere Community
- Weniger Tutorials und Best Practices

#### Zitat aus der Praxis

> "Nomad ist einfacher zu starten, aber das Fehlen von Helm-ähnlichen Tools macht komplexe Deployments herausfordernder. Der Mindset-Wechsel war für mich als K8s-Praktikerin zunächst schwierig."
>
> — Iris Carrera, SRE bei HashiCorp

### Lernkurve & Betrieb

**Time to Production:**

```
Nomad:
Setup → 1-2 Tage
Produktiv → 1 Woche
Expertise → 2-4 Wochen

Kubernetes:
Setup → 1-2 Wochen (Managed: 1-2 Tage)
Produktiv → 1-2 Monate
Expertise → 3-6 Monate
```

**Betriebsaufwand (FTE):**

| Cluster-Größe           | Nomad       | Kubernetes  | Differenz          |
| ----------------------- | ----------- | ----------- | ------------------ |
| **Small (10-50 Nodes)** | 0.2-0.5 FTE | 0.5-1.0 FTE | **50-60% weniger** |
| **Medium (50-200)**     | 0.5-1.0 FTE | 1.5-2.5 FTE | **60-70% weniger** |
| **Large (200+)**        | 1.0-2.0 FTE | 3.0-5.0 FTE | **60-70% weniger** |

---

## 2. Marktanalyse & Adoption

### Global - Kubernetes dominiert

**Container Orchestration Market Share (2024):**

```
Kubernetes:   ████████████████████ 88%
Docker Swarm: ██ 5%
Nomad:        ██ 4%
Andere:       █ 3%
```

_Quelle: CNCF Survey 2024_

### DACH-Region - Nomad-Nutzung

**Geschätzte Unternehmen mit Nomad in Production:**

- **Deutschland**: <50 Unternehmen
- **Kubernetes**: >5000 Unternehmen

**Problem:** Fehlende kritische Masse führt zu:

- Wenig lokale Expertise
- Kaum Community-Events
- Schwierige Rekrutierung

### Job-Markt Deutschland

**Indeed.de Stellenausschreibungen (Nov 2024):**

| Skill          | Anzahl Stellen |
| -------------- | -------------- |
| **Kubernetes** | ~3.500         |
| **Docker**     | ~2.800         |
| **Nomad**      | ~15-20         |

**LinkedIn-Suche (DACH):**

- "Kubernetes Engineer": 2.000+ Profile
- "Nomad Engineer": <50 Profile

**Fazit:** Extrem limitierter Talentpool für Nomad in DE.

### Managed Services

| Anbieter         | Kubernetes | Nomad         |
| ---------------- | ---------- | ------------- |
| **AWS**          | ✅ EKS     | ❌            |
| **Azure**        | ✅ AKS     | ❌            |
| **Google Cloud** | ✅ GKE     | ❌            |
| **HashiCorp**    | N/A        | ✅ HCP (Beta) |

**HCP Nomad:**

- Seit 2023 in Public Beta
- Keine garantierte EU-Region
- Keine Enterprise-SLAs

---

## 3. Kostenanalyse

### Infrastruktur-Kosten (Azure, 100 Workloads)

#### Nomad Setup (Self-Managed)

```
Control Plane:
- 3x Nomad Server (Standard_D2s_v5)  = €200/Monat

Worker Nodes:
- 10x Client (Standard_D4s_v5)        = €1.330/Monat

Netzwerk & Monitoring:
- Load Balancer, VNet, Logs           = €200/Monat
─────────────────────────────────────────────────
GESAMT NOMAD:                          ~€1.730/Monat
```

#### Kubernetes Setup (AKS)

```
Control Plane:
- AKS Managed                          = €0 (Free)

Worker Nodes:
- 10x Nodes (Standard_D4s_v5)         = €1.330/Monat

Netzwerk & Monitoring:
- Load Balancer, VNet, Insights       = €350/Monat
─────────────────────────────────────────────────
GESAMT AKS:                            ~€1.680/Monat
```

**Infrastruktur-Differenz:** ~€50/Monat (3%)

### Gesamt-Kostenvergleich (inkl. Personal)

**Annahmen:**

- DevOps Engineer: €90.000/Jahr Vollkosten

| Kostenfaktor         | Nomad (Self)      | AKS (Managed)     | Differenz |
| -------------------- | ----------------- | ----------------- | --------- |
| **Infrastruktur**    | €20.760           | €20.160           | +€600     |
| **Betrieb**          | 0.5 FTE = €45.000 | 0.3 FTE = €27.000 | +€18.000  |
| **Initial Setup**    | €10.000           | €5.000            | +€5.000   |
| **Training**         | €5.000            | €8.000            | -€3.000   |
| **GESAMT Jahr 1**    | **€80.760**       | **€60.160**       | **+34%**  |
| **GESAMT ab Jahr 2** | **€65.760**       | **€55.160**       | **+19%**  |

**Fazit:** Nomad ist **teurer** durch höheren Self-Management-Aufwand.

### Skalierungs-Kosten (500 Workloads)

| Faktor        | Nomad         | AKS           |
| ------------- | ------------- | ------------- |
| Infrastruktur | ~€8.000/Monat | ~€8.000/Monat |
| Personal      | 1.5-2.0 FTE   | 0.8-1.2 FTE   |
| **Jährlich**  | **~€231.000** | **~€168.000** |
| **Differenz** |               | **+37%**      |

---

## 4. Governance & Compliance

### Compliance-Anforderungen

| Anforderung    | Nomad        | Kubernetes (AKS) | Details                |
| -------------- | ------------ | ---------------- | ---------------------- |
| **DSGVO**      | ⚠️ Self only | ✅ Managed       | AKS hat EU-Compliance  |
| **BSI C5**     | ❌           | ✅ Zertifiziert  | Public-Sector kritisch |
| **SOC 2**      | ⚠️ Eigen     | ✅ Zertifiziert  | FinTech relevant       |
| **ISO 27001**  | ⚠️ Eigen     | ✅ Zertifiziert  | Enterprise Standard    |
| **Audit-Logs** | ⚠️ Basis     | ✅ Vollständig   | Azure Monitor          |

**Problem:** Nomad Self-Managed = **volle Compliance-Verantwortung**

### Security & Zugriffskontrolle

| Feature               | Nomad                     | Kubernetes             |
| --------------------- | ------------------------- | ---------------------- |
| **RBAC**              | ⚠️ ACL (weniger granular) | ✅ Vollständig         |
| **Multi-Tenancy**     | ⚠️ Limitiert              | ✅ Namespaces+Policies |
| **Pod Security**      | ❌                        | ✅ Standards           |
| **Secret Encryption** | ⚠️ Vault                  | ✅ Native              |
| **Network Policies**  | ❌ Extern                 | ✅ Native              |

---

## 5. Use-Case Matrix

### Wann macht Nomad Sinn?

| Use Case                     | Nomad      | K8s        | Empfehlung     |
| ---------------------------- | ---------- | ---------- | -------------- |
| **Greenfield Microservices** | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ | **Kubernetes** |
| **Legacy Migration**         | ⭐⭐⭐⭐   | ⭐⭐       | **Nomad**      |
| **Batch/Data Processing**    | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     | **Nomad**      |
| **Edge Computing**           | ⭐⭐⭐⭐   | ⭐⭐⭐     | **Nomad**      |
| **Multi-Cloud**              | ⭐⭐⭐⭐   | ⭐⭐⭐     | **Nomad**      |
| **Startup (<10 Devs)**       | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     | **Nomad**      |
| **Enterprise (>100 Devs)**   | ⭐⭐       | ⭐⭐⭐⭐⭐ | **Kubernetes** |
| **Highly Regulated**         | ⭐⭐       | ⭐⭐⭐⭐⭐ | **Kubernetes** |

### Ideale Nomad-Kunden

**Profil:**

- **Größe**: KMU, Startups (10-100 Mitarbeiter)
- **Tech**: Mixed Workloads (Container+VMs)
- **DevOps-Reife**: Basis bis Mittel
- **Cloud**: Multi-Cloud oder On-Premise
- **Compliance**: Standard (keine BSI/SOC2)

**Beispiel-Szenarien:**

1. SaaS-Startup mit schnellem MVP
2. Legacy-Modernisierung (schrittweise)
3. IoT-Edge-Orchestrierung
4. Batch-/Data-Processing-Pipelines

### Ungeeignete Szenarien

❌ Große Enterprises mit K8s-Teams  
❌ Highly Regulated (Banken, Public Sector)  
❌ Cloud-Native Startups  
❌ Globale Konzerne (Multi-Region)  
❌ >50 Microservices (K8s-Ecosystem überlegen)

---

## 6. Risiko-Analyse

### Technische Risiken

| Risiko             | Wahrscheinlichkeit | Impact    | Nomad       | K8s     |
| ------------------ | ------------------ | --------- | ----------- | ------- |
| **Skill-Mangel**   | Hoch               | Hoch      | ❌ Kritisch | ⚠️ Hoch |
| **Feature-Lücken** | Mittel             | Mittel    | ⚠️          | ✅      |
| **Skalierung**     | Niedrig            | Hoch      | ⚠️          | ✅      |
| **Security**       | Niedrig            | Sehr Hoch | ⚠️          | ✅      |

### Business-Risiken

| Risiko                | Nomad                  | Kubernetes     |
| --------------------- | ---------------------- | -------------- |
| **Markt-Akzeptanz**   | ❌ Limitiert           | ✅ Standard    |
| **Kunden-Akzeptanz**  | ⚠️ Erklärungsbedürftig | ✅ Etabliert   |
| **Rekrutierung**      | ❌ Sehr schwierig      | ✅ Großer Pool |
| **Partner-Ecosystem** | ⚠️ Klein               | ✅ Sehr groß   |
| **Long-Term Support** | ⚠️ HashiCorp           | ✅ CNCF        |

---

# Teil 4: Fazit & Empfehlungen (5 Min)

## Zusammenfassung

### Stärken von Nomad

✅ **Einfachheit**: Deutlich einfacher zu lernen  
✅ **Multi-Workload**: Mehr als nur Container  
✅ **Ressourcen-Effizienz**: Geringerer Overhead  
✅ **Portabilität**: Cloud-agnostic  
✅ **Schnelligkeit**: Schnelles Setup

### Schwächen von Nomad

❌ **Marktposition**: Sehr limitiert in DACH  
❌ **Talentpool**: Kaum Experten verfügbar  
❌ **Ecosystem**: Deutlich kleiner  
❌ **Compliance**: Kein Managed Service EU  
❌ **Feature-Set**: Weniger als K8s

## Empfehlungen für unsere Beratung

### Empfehlung 1: Fokus auf Kubernetes

**Begründung:**

- Industry Standard mit 88% Marktanteil
- Großer Talentpool in Deutschland
- Bessere Kundenakzeptanz
- Managed Services verfügbar (AKS, EKS, GKE)
- Vollständiges Ecosystem

**Aktion:** Kubernetes bleibt unser **Haupt-Orchestrator** für Kundenprojekte.

### Empfehlung 2: Nomad für Nischen-Use-Cases

**Wann Nomad vorschlagen:**

1. **Legacy-Modernisierung**: Mixed Workloads (Container + VMs)
2. **Edge/IoT**: Leichtgewichtige Orchestrierung
3. **Startups**: Schneller MVP, niedrige Komplexität
4. **Multi-Cloud**: Portabilität ohne K8s-Komplexität
5. **Batch-Processing**: Einfache Job-Orchestrierung

**Aktion:** Nomad als **Spezial-Tool** im Portfolio behalten.

### Empfehlung 3: Skill-Aufbau

**Nomad-Kompetenz:**

- **1-2 Spezialisten** im Team ausbilden
- **Pilot-Projekt** intern durchführen (z.B. CI/CD)
- **Keine breite Schulung** notwendig

**Kubernetes-Kompetenz:**

- **Weiter ausbauen**: Mehr CKA/CKAD Zertifizierungen
- **GitOps-Skills**: ArgoCD, Flux
- **Service Mesh**: Istio, Linkerd

### Empfehlung 4: Marketing-Strategie

**Positionierung:**

- "Kubernetes-First" Ansatz in Marketing
- Nomad als "Alternative für spezielle Anforderungen"
- Fokus auf Kubernetes-Expertise nach außen

## Entscheidungsbaum für Kundenprojekte

```
                    ┌────────────────────┐
                    │  Neues Projekt     │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Reguliert?        │
                    │  (BSI, SOC2, etc.) │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │     Ja              │   Nein
                    │                     │
            ┌───────▼────────┐   ┌──────▼───────────┐
            │  KUBERNETES    │   │  Workload-Typ?   │
            │  (AKS/EKS/GKE) │   └──────┬───────────┘
            └────────────────┘           │
                                ┌────────▼────────────┐
                                │  Nur Container?     │
                                └────────┬────────────┘
                                         │
                        ┌────────────────┴─────────────┐
                        │ Ja                           │ Nein (Mixed)
                ┌───────▼────────┐            ┌───────▼────────┐
                │  Team >50?     │            │  NOMAD         │
                └───────┬────────┘            │  (Consider)    │
                        │                      └────────────────┘
        ┌───────────────┴──────────────┐
        │ Ja                            │ Nein (<50)
 ┌──────▼─────────┐           ┌────────▼────────┐
 │  KUBERNETES    │           │  Kosten/Zeit    │
 │  (Ecosystem)   │           │  kritisch?      │
 └────────────────┘           └────────┬────────┘
                                       │
                        ┌──────────────┴──────────────┐
                        │ Ja                          │ Nein
                ┌───────▼────────┐           ┌───────▼────────┐
                │  NOMAD         │           │  KUBERNETES    │
                │  (Einfachheit) │           │  (Future-Proof)│
                └────────────────┘           └────────────────┘
```

## ROI-Kalkulation

### Szenario: 100-Node Cluster über 3 Jahre

| Faktor        | Nomad (Self) | Kubernetes (AKS) | Differenz           |
| ------------- | ------------ | ---------------- | ------------------- |
| **Jahr 1**    | €80.760      | €60.160          | +€20.600            |
| **Jahr 2**    | €65.760      | €55.160          | +€10.600            |
| **Jahr 3**    | €65.760      | €55.160          | +€10.600            |
| **Gesamt 3J** | **€212.280** | **€170.480**     | **+€41.800 (+24%)** |

**Breakeven:** Nomad wird nie günstiger als managed Kubernetes

## Schlussfolgerung

### Kernerkenntnisse aus der Evaluierung

**Nomads Stärken sind real:**

- ✅ Deutlich einfacher zu lernen und zu betreiben
- ✅ Exzellenter Multi-Workload-Support (Container + VMs + Binaries)
- ✅ Geringerer Ressourcen-Overhead
- ✅ Schnelleres Scheduling (Batch-Jobs)
- ✅ Native Multi-Region-Federation

**Aber: Kritische Schwächen überwiegen für Enterprise:**

- ❌ **Keine CRDs** → Limitierte Plattform-Abstraktion
- ❌ **Kleines Ecosystem** → Mehr Custom-Development
- ❌ **Schwache Community** in DACH → Rekrutierungsproblem
- ❌ **Fehlende Managed Services** in EU → Höhere Betriebskosten
- ❌ **GitOps-Immaturity** → Weniger Automatisierung

**Kubernetes-Vorteile sind entscheidend:**

- ✅ CRDs & Operator Pattern → Enterprise-Plattformen
- ✅ Riesiges Ecosystem → Fertige Lösungen
- ✅ Managed Services → Niedrigere TCO
- ✅ Community & Marktposition → Langfristig sicher
- ✅ Talent-Verfügbarkeit → Einfache Skalierung

### Für unsere Firma

1. ✅ **Kubernetes bleibt Haupt-Standard**

   - Primäre Marketing-Botschaft
   - Hauptfokus für Skill-Entwicklung
   - Default für 90% der Projekte

2. ⚠️ **Nomad als taktische Nischen-Option**

   - Für spezifische Use Cases (Legacy, Edge, Batch)
   - Differenzierungsmerkmal ("Wir kennen Alternativen")
   - Nicht aktiv vermarkten, aber verfügbar

3. ✅ **Skill-Aufbau fokussiert**

   - 1-2 Nomad-Spezialisten (die auch K8s können)
   - Team-weite K8s-Kompetenz weiter ausbauen
   - CRD & Operator-Entwicklung als Differentiator

4. ⚠️ **Marketing: "Technologie-Agnostisch, K8s-Kompetent"**
   - "Kubernetes-First, aber nicht Kubernetes-Only"
   - Nomad für die richtigen Probleme

### Für unsere Kunden

**Default-Empfehlung:** Managed Kubernetes (AKS/EKS/GKE)

**Begründung:**

- Industry Standard mit langfristiger Zukunftssicherheit
- Riesiges Ecosystem für alle Anforderungen
- Managed Services senken Betriebskosten
- Einfache Rekrutierung von Talenten
- CRDs ermöglichen Platform Engineering

**Nomad-Empfehlung nur wenn:**

1. **Legacy-Modernisierung** mit Mixed Workloads

   - Schrittweise Container-Einführung
   - VMs parallel zu Container
   - Zeitdruck für MVP

2. **Startup-Phase** (<20 Mitarbeiter)

   - Fokus auf Time-to-Market
   - Kleines Team ohne K8s-Expertise
   - MVP-Strategie mit späterer Migration

3. **Edge/IoT-Computing**

   - Ressourcen-limitierte Umgebungen
   - Viele kleine Deployments
   - Offline-Fähigkeit wichtig

4. **Batch/Data-Processing-Fokus**

   - Primär kurzlebige Jobs
   - Wenig Microservices
   - Scheduling-Performance wichtig

5. **Multi-Cloud-Anforderung ohne K8s-Wissen**
   - Portabilität absolut kritisch
   - Team hat keine K8s-Expertise
   - Einfachheit wichtiger als Features

**Explizite Ausschluss-Kriterien für Nomad:**

- ❌ Regulierte Industrien (Banking, Healthcare, Public Sector)
- ❌ Große Enterprise (>100 Entwickler)
- ❌ Cloud-Native Microservices-Architektur
- ❌ Anforderung an Platform Engineering
- ❌ Compliance-kritische Anforderungen (BSI C5, SOC2)

---

## TL;DR - Die wichtigsten Erkenntnisse

```
┌─────────────────────────────────────────────────────────────────┐
│  NOMAD vs. KUBERNETES - KERNERKENNTNIS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✅ Nomad ist EINFACHER, ABER...                                │
│  ❌ Kubernetes ist VOLLSTÄNDIGER und ZUKUNFTSSICHERER           │
│                                                                  │
│  EMPFEHLUNG für unsere Firma:                                   │
│  → Kubernetes als Haupt-Standard (90% der Projekte)            │
│  → Nomad für spezifische Nischen (10% der Projekte)            │
│                                                                  │
│  KRITISCHE FAKTOREN gegen Nomad in Enterprise:                  │
│  1. Keine CRDs → Limitiertes Platform Engineering              │
│  2. Kleines Ecosystem → Mehr Custom-Development                 │
│  3. Schwache DACH-Community → Rekrutierungsproblem             │
│  4. Keine EU Managed Services → Höhere Betriebskosten          │
│  5. Geringere Marktakzeptanz → Risiko für Kunden              │
│                                                                  │
│  WANN MACHT NOMAD SINN:                                         │
│  • Legacy-Modernisierung (Mixed Workloads)                      │
│  • Startups in MVP-Phase (<20 Entwickler)                      │
│  • Edge/IoT mit Ressourcen-Limitierung                         │
│  • Batch-Processing (Scheduling-Performance)                    │
│                                                                  │
│  KOSTEN-REALITÄT:                                               │
│  Nomad (Self-Managed) ist 20-37% TEURER als managed K8s        │
│  durch höheren Personal- und Betriebsaufwand                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Ein-Satz-Fazit

**"Nomad löst reale Probleme (Einfachheit, Multi-Workload), aber für Enterprise-Beratung überwiegen die Nachteile (Ecosystem, Community, CRDs, TCO) – Kubernetes bleibt der Standard, Nomad ist eine taktische Nischen-Alternative."**

---

## Diskussion & Q&A

### Offene Fragen

1. Sollen wir Nomad aktiv vermarkten?
2. Wie viele Spezialisten brauchen wir?
3. Pilot-Projekt intern starten?
4. HCP Nomad testen sobald EU-Region verfügbar?

### Nächste Schritte

1. **Kurzfristig (1-3 Monate)**:

   - Entscheidung: Nomad ins Portfolio?
   - 1-2 Berater schulen
   - Internes Pilot-Projekt

2. **Mittelfristig (3-6 Monate)**:

   - Use-Case-Katalog erstellen
   - Marketing-Material
   - Erstes Kundenprojekt (klein)

3. **Langfristig (6-12 Monate)**:
   - Evaluierung nach 5-10 Projekten
   - ROI-Analyse
   - Strategie anpassen

---

## Anhang

### Weiterführende Ressourcen

**Nomad:**

- [HashiCorp Nomad Docs](https://developer.hashicorp.com/nomad)
- [Nomad Learn Tutorials](https://learn.hashicorp.com/nomad)
- [HCP Nomad](https://cloud.hashicorp.com/products/nomad)
- [Nomad for Kubernetes Practitioners](Nomad_for_Kubernetes_Practitioners_Summary.md)

**Kubernetes:**

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [CNCF Landscape](https://landscape.cncf.io/)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/)

**Vergleiche:**

- [Nomad vs K8s (HashiCorp)](https://www.nomadproject.io/intro/vs/kubernetes)
- [CNCF Survey 2024](https://www.cncf.io/reports/cncf-annual-survey-2024/)

**Features:**

- Terraform IaC für Azure
- Ansible Automation
- GitHub Actions CI/CD
- Example Jobs
- Vollständige Dokumentation

---

**Ende der Präsentation**

_Fragen & Diskussion_
