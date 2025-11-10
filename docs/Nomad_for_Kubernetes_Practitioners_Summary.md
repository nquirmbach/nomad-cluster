# Nomad for Kubernetes Practitioners -- Zusammenfassung

## 🧭 Ziel & Motivation

**Autorin:** Iris Carrera (SRE bei HashiCorp)\
**Motivation:** Erfahrungen beim Umstieg von Kubernetes zu Nomad und
wachsendes Community-Interesse an Nomad (z. B. Home-Server-Setups,
Blogposts, Hacker News).

------------------------------------------------------------------------

## 📋 Agenda

1.  **Core Comparison** -- Architektur und Konzepte im Vergleich zu
    Kubernetes\
2.  **Reflections** -- Erfahrungen beim Umstieg\
3.  **Getting Started with Nomad** -- Praxisanleitung und CLI-Kommandos

------------------------------------------------------------------------

## ⚙️ Core Comparison (Kernvergleich)

### Überblick

-   **Kubernetes:** Container Workload Orchestration, Service Discovery,
    Secrets Management\
-   **Nomad:** Allgemeine Workload-Orchestrierung (nicht nur Container),
    Service Discovery (über Consul), Secrets Management (über Vault)

### Architekturvergleich

**Kubernetes:** kubelet, Container Runtime, kube-proxy auf Nodes;
Control Plane mit kube-api-server, etcd, Scheduler, Controller-Manager.\
**Nomad:** Nomad-Agent im Client- oder Server-Modus, Cluster-State über
Raft, optionale Integration mit Consul für Service Discovery und Vault
für Secrets Management.

### Einheiten der Arbeit

  -----------------------------------------------------------------------
  Konzept                Kubernetes                    Nomad
  ---------------------- ----------------------------- ------------------
  Kleinste Einheit       **Pod** (mehrere Container)   **Task**
                                                       (Container,
                                                       Batch-Prozess
                                                       etc.)

  Gruppierung            **ReplicaSet**                **Task Group**

  Deployments            **Deployment (Pods +          **Job (mehrere
                         ReplicaSets)**                Task Groups)**
  -----------------------------------------------------------------------

### Service Discovery & Load Balancing

-   **Kubernetes:** Services, kube-proxy und DNS für Service Discovery;
    Load Balancer & Ingress-Controller (nginx, Traefik, Envoy).\
-   **Nomad:** Consul integriert DNS, Load Balancing & Service Registry;
    Unterstützung von Envoy, HAProxy, Traefik usw.

### Secrets Management

-   **Kubernetes:** Secrets als Objekte oder via Vault.\
-   **Nomad:** Direkte Vault-Integration, Secrets über Template-Stanzas
    an Tasks übergeben.

------------------------------------------------------------------------

## 💡 Reflections

-   Einfacherer Einstieg in Nomad 🎉\
-   Umdenken nötig, da weniger Abstraktionsschichten als bei Helm Charts
    🤔\
-   Wunsch nach einem „Helm-ähnlichen" Tool für Nomad 🙏

------------------------------------------------------------------------

## 🧑‍💻 Getting Started mit Nomad

**Installation:**\
<https://nomadproject.io/downloads>

**Wichtige Befehle:**

``` bash
nomad agent -dev           # Startet lokalen Dev-Agent
nomad ui                   # Startet Web UI
nomad job run <file>       # Deployt Job
nomad job status           # Zeigt Status
nomad alloc logs -job <name>  # Zeigt Logs
```

------------------------------------------------------------------------

## 🏁 Fazit

Nomad ist eine **flexible, leichtgewichtige Alternative zu Kubernetes**,
insbesondere für heterogene Workloads und kleinere Umgebungen.\
Die Integration mit HashiCorp-Tools (**Consul**, **Vault**) ist nahtlos
und ermöglicht eine klare, einfache Architektur ohne komplexe
Abstraktionen.
