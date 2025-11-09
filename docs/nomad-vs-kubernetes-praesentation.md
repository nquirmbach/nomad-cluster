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

| Zeit | Thema | Details |
|------|-------|---------|
| 0-5 Min | Einführung in Nomad | Was ist Nomad? Kernkonzepte |
| 5-15 Min | Live-Demo | Azure-Setup, Deployment, Skalierung |
| 15-25 Min | Evaluierung & Vergleich | Tech-Stack, Markt, Kosten, Governance |
| 25-30 Min | Fazit & Q&A | Empfehlungen, Diskussion |

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

| Aspekt | Nomad | Kubernetes |
|--------|-------|------------|
| **Binärgröße** | ~100 MB | >1 GB |
| **Komponenten** | 1 Binary | 10+ Komponenten |
| **Lernkurve** | Flach (~1 Woche) | Steil (~3-6 Monate) |
| **Workload-Typen** | Multi (Docker, VMs, Binaries) | Primär Container |
| **Setup-Zeit** | Minuten | Stunden/Tage |

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

| Komponente | Nomad | Kubernetes |
|------------|-------|------------|
| **Control Plane** | 1 Binary | 4+ Komponenten |
| **Data Plane** | 1 Binary | 2+ Komponenten |
| **Service Discovery** | Integriert | Externe Lösung |
| **Storage** | Basic (CSI) | Erweitert (PV/PVC) |
| **Networking** | Einfach | Komplex (CNI) |

### Feature-Vergleich

| Feature | Nomad | Kubernetes | Bewertung |
|---------|-------|------------|-----------|
| **Container-Orchestrierung** | ✅ Sehr gut | ✅ Exzellent | K8s leicht vorne |
| **Multi-Workload** | ✅ Native | ⚠️ Mit Plugins | Nomad überlegen |
| **Service Mesh** | ⚠️ Via Consul | ✅ Istio, Linkerd | K8s reifer |
| **Auto-Scaling** | ✅ Job & Node | ✅ HPA/VPA/CA | Vergleichbar |
| **Secrets Management** | ⚠️ Basic/Vault | ✅ Native | K8s besser |
| **GitOps** | ⚠️ Limitiert | ✅ ArgoCD/Flux | K8s ausgereifter |
| **Observability** | ⚠️ Basis | ✅ Umfangreich | K8s deutlich besser |
| **Multi-Tenancy** | ⚠️ Namespaces | ✅ Namespaces+RBAC | K8s besser |

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

| Cluster-Größe | Nomad | Kubernetes | Differenz |
|---------------|-------|------------|-----------|
| **Small (10-50 Nodes)** | 0.2-0.5 FTE | 0.5-1.0 FTE | **50-60% weniger** |
| **Medium (50-200)** | 0.5-1.0 FTE | 1.5-2.5 FTE | **60-70% weniger** |
| **Large (200+)** | 1.0-2.0 FTE | 3.0-5.0 FTE | **60-70% weniger** |

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

*Quelle: CNCF Survey 2024*

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

| Skill | Anzahl Stellen |
|-------|----------------|
| **Kubernetes** | ~3.500 |
| **Docker** | ~2.800 |
| **Nomad** | ~15-20 |

**LinkedIn-Suche (DACH):**
- "Kubernetes Engineer": 2.000+ Profile
- "Nomad Engineer": <50 Profile

**Fazit:** Extrem limitierter Talentpool für Nomad in DE.

### Managed Services

| Anbieter | Kubernetes | Nomad |
|----------|------------|-------|
| **AWS** | ✅ EKS | ❌ |
| **Azure** | ✅ AKS | ❌ |
| **Google Cloud** | ✅ GKE | ❌ |
| **HashiCorp** | N/A | ✅ HCP (Beta) |

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

| Kostenfaktor | Nomad (Self) | AKS (Managed) | Differenz |
|--------------|--------------|---------------|-----------|
| **Infrastruktur** | €20.760 | €20.160 | +€600 |
| **Betrieb** | 0.5 FTE = €45.000 | 0.3 FTE = €27.000 | +€18.000 |
| **Initial Setup** | €10.000 | €5.000 | +€5.000 |
| **Training** | €5.000 | €8.000 | -€3.000 |
| **GESAMT Jahr 1** | **€80.760** | **€60.160** | **+34%** |
| **GESAMT ab Jahr 2** | **€65.760** | **€55.160** | **+19%** |

**Fazit:** Nomad ist **teurer** durch höheren Self-Management-Aufwand.

### Skalierungs-Kosten (500 Workloads)

| Faktor | Nomad | AKS |
|--------|-------|-----|
| Infrastruktur | ~€8.000/Monat | ~€8.000/Monat |
| Personal | 1.5-2.0 FTE | 0.8-1.2 FTE |
| **Jährlich** | **~€231.000** | **~€168.000** |
| **Differenz** | | **+37%** |

---

## 4. Governance & Compliance

### Compliance-Anforderungen

| Anforderung | Nomad | Kubernetes (AKS) | Details |
|-------------|-------|------------------|---------|
| **DSGVO** | ⚠️ Self only | ✅ Managed | AKS hat EU-Compliance |
| **BSI C5** | ❌ | ✅ Zertifiziert | Public-Sector kritisch |
| **SOC 2** | ⚠️ Eigen | ✅ Zertifiziert | FinTech relevant |
| **ISO 27001** | ⚠️ Eigen | ✅ Zertifiziert | Enterprise Standard |
| **Audit-Logs** | ⚠️ Basis | ✅ Vollständig | Azure Monitor |

**Problem:** Nomad Self-Managed = **volle Compliance-Verantwortung**

### Security & Zugriffskontrolle

| Feature | Nomad | Kubernetes |
|---------|-------|------------|
| **RBAC** | ⚠️ ACL (weniger granular) | ✅ Vollständig |
| **Multi-Tenancy** | ⚠️ Limitiert | ✅ Namespaces+Policies |
| **Pod Security** | ❌ | ✅ Standards |
| **Secret Encryption** | ⚠️ Vault | ✅ Native |
| **Network Policies** | ❌ Extern | ✅ Native |

---

## 5. Use-Case Matrix

### Wann macht Nomad Sinn?

| Use Case | Nomad | K8s | Empfehlung |
|----------|-------|-----|------------|
| **Greenfield Microservices** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **Kubernetes** |
| **Legacy Migration** | ⭐⭐⭐⭐ | ⭐⭐ | **Nomad** |
| **Batch/Data Processing** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | **Nomad** |
| **Edge Computing** | ⭐⭐⭐⭐ | ⭐⭐⭐ | **Nomad** |
| **Multi-Cloud** | ⭐⭐⭐⭐ | ⭐⭐⭐ | **Nomad** |
| **Startup (<10 Devs)** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | **Nomad** |
| **Enterprise (>100 Devs)** | ⭐⭐ | ⭐⭐⭐⭐⭐ | **Kubernetes** |
| **Highly Regulated** | ⭐⭐ | ⭐⭐⭐⭐⭐ | **Kubernetes** |

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

| Risiko | Wahrscheinlichkeit | Impact | Nomad | K8s |
|--------|-------------------|--------|-------|-----|
| **Skill-Mangel** | Hoch | Hoch | ❌ Kritisch | ⚠️ Hoch |
| **Feature-Lücken** | Mittel | Mittel | ⚠️ | ✅ |
| **Skalierung** | Niedrig | Hoch | ⚠️ | ✅ |
| **Security** | Niedrig | Sehr Hoch | ⚠️ | ✅ |

### Business-Risiken

| Risiko | Nomad | Kubernetes |
|--------|-------|------------|
| **Markt-Akzeptanz** | ❌ Limitiert | ✅ Standard |
| **Kunden-Akzeptanz** | ⚠️ Erklärungsbedürftig | ✅ Etabliert |
| **Rekrutierung** | ❌ Sehr schwierig | ✅ Großer Pool |
| **Partner-Ecosystem** | ⚠️ Klein | ✅ Sehr groß |
| **Long-Term Support** | ⚠️ HashiCorp | ✅ CNCF |

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

| Faktor | Nomad (Self) | Kubernetes (AKS) | Differenz |
|--------|--------------|------------------|-----------|
| **Jahr 1** | €80.760 | €60.160 | +€20.600 |
| **Jahr 2** | €65.760 | €55.160 | +€10.600 |
| **Jahr 3** | €65.760 | €55.160 | +€10.600 |
| **Gesamt 3J** | **€212.280** | **€170.480** | **+€41.800 (+24%)** |

**Breakeven:** Nomad wird nie günstiger als managed Kubernetes

## Schlussfolgerung

### Für unsere Firma

1. ✅ **Kubernetes bleibt Standard**
2. ⚠️ **Nomad als Nischen-Option**
3. ✅ **Skill-Aufbau fokussiert**
4. ⚠️ **Marketing: K8s-First**

### Für unsere Kunden

**Default-Empfehlung:** Managed Kubernetes (AKS/EKS/GKE)

**Nomad-Empfehlung nur wenn:**
- Startup mit <20 Mitarbeitern
- Legacy-Mixed-Workloads
- Edge/IoT-Anforderungen
- Explizit Multi-Cloud ohne K8s
- Keine Compliance-Anforderungen

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

**Kubernetes:**
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [CNCF Landscape](https://landscape.cncf.io/)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/)

**Vergleiche:**
- [Nomad vs K8s (HashiCorp)](https://www.nomadproject.io/intro/vs/kubernetes)
- [CNCF Survey 2024](https://www.cncf.io/reports/cncf-annual-survey-2024/)

### Demo-Repository

**GitHub:** [github.com/[username]/nomad-cluster](https://github.com/[username]/nomad-cluster)

**Features:**
- Terraform IaC für Azure
- Ansible Automation
- GitHub Actions CI/CD
- Example Jobs
- Vollständige Dokumentation

---

**Ende der Präsentation**

*Fragen & Diskussion*
