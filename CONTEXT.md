# Project Context: Nomad Cluster on Azure

## Fachlicher Kontext

### Projektziel
Automatisierte Bereitstellung eines hochverfügbaren **HashiCorp Nomad Clusters** in Azure für Container- und Workload-Orchestrierung. Nomad ist eine schlanke Alternative zu Kubernetes mit reduzierter Komplexität.

### Use Case
- **Workload-Orchestrierung**: Deployment und Management von containerisierten und non-containerisierten Anwendungen
- **Multi-Environment Support**: Separate Umgebungen für Development, Staging und Production
- **Self-Service Infrastructure**: Vollautomatisiertes Provisioning via GitHub Actions

### Stakeholder Value
- **DevOps Teams**: Schnelles Deployment ohne manuelle Infrastruktur-Konfiguration
- **Entwickler**: Einfaches Job-Deployment auf Nomad-Cluster
- **Operations**: Reduzierter operativer Aufwand durch IaC und Automation

---

## Technischer Kontext

### Architektur-Überblick
```
GitHub Actions (OIDC Auth)
    ↓
Azure Cloud
    ├── Terraform → Infrastructure Provisioning
    │   ├── VNet + Subnets (10.0.0.0/16)
    │   ├── 3x Nomad Server VMs (Standard_B2s)
    │   ├── 2-Nx Client VMs via VMSS (Auto-Scaling)
    │   ├── Load Balancer (Nomad UI: 4646, Consul UI: 8500)
    │   ├── NSGs (Network Security)
    │   ├── Azure Container Registry (ACR)
    │   └── Key Vault + Log Analytics
    │
    └── Ansible → Configuration Management
        ├── Server Configuration (SSH via Load Balancer NAT)
        ├── Consul Installation (Co-located)
        ├── Nomad Server Setup
        └── Client Configuration (Cloud-Init, keine SSH)
```

### Tech Stack

| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| **IaC** | Terraform 1.5+ | Azure-Ressourcen-Provisioning |
| **Config Mgmt** | Ansible 9.0+ | Server-Konfiguration |
| **Orchestration** | Nomad + Consul | Workload-Scheduling + Service Discovery |
| **CI/CD** | GitHub Actions | Automated Deployment Pipeline |
| **Cloud** | Azure | Hosting Platform |
| **Container Registry** | Azure Container Registry (ACR) | Image Storage |
| **Auth** | OIDC Federated Identity | Passwordless Authentication |
| **Secrets** | Azure Key Vault | Secret Management |

### Projektstruktur

```
nomad-cluster/
├── .github/workflows/          # CI/CD Pipelines
│   ├── provision-cluster.yml   # Infrastructure + Configuration
│   └── deploy-app.yml          # Application Deployment
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # Root Module
│   ├── backend.tf              # Remote State (Azure Storage)
│   ├── modules/
│   │   ├── network/            # VNet, NSGs, Load Balancer
│   │   ├── compute/            # VMs, VMSS
│   │   ├── services/           # Key Vault, ACR, Log Analytics
│   │   └── ssh/                # SSH Key Generation
│   └── environments/
│       ├── dev/                # Dev-specific tfvars
│       ├── stg/                # Staging-specific tfvars
│       └── prd/                # Production-specific tfvars
│
├── ansible/                    # Configuration Management
│   ├── playbooks/
│   │   ├── site.yml           # Main playbook (includes all)
│   │   ├── common.yml         # Base setup (all nodes)
│   │   ├── consul.yml         # Consul Server installation
│   │   ├── nomad-server.yml   # Nomad Server configuration
│   │   └── nomad-client.yml   # Nomad Client setup (fallback)
│   └── templates/
│       ├── consul-*.hcl.j2    # Consul configuration templates
│       └── nomad-*.hcl.j2     # Nomad configuration templates
│
├── jobs/                       # Nomad Job Definitions
│   ├── example.nomad          # Example job spec
│   └── server-info.nomad       # Server info web application job
│
├── app/                        # Demo Flask Application
│   ├── Dockerfile             # Container image
│   ├── app.py                 # Flask app (server info display)
│   └── Taskfile.yml           # Local development tasks
│
├── scripts/
│   ├── setup-federated-identity.sh  # Azure OIDC setup automation
│   └── ssh-to-nomad-client.sh      # Client SSH helper
│
└── docs/                       # Documentation
    ├── architecture.md         # Full production architecture
    ├── architecture-simple.md  # Simplified dev/test setup
    ├── setup.md               # Complete setup guide
    ├── security.md            # Security best practices
    └── acr-integration.md     # ACR integration details
```

### Deployment Flow

1. **GitHub Actions triggered** (manual/push)
2. **Terraform** provisions Azure infrastructure
   - Creates VNet, VMs, Load Balancer, ACR, Key Vault
   - Generates SSH keys dynamically
   - Outputs inventory for Ansible
3. **Ansible** configures server nodes
   - Installs Consul Server (co-located)
   - Installs Nomad Server
   - Configures services and starts daemons
4. **Client Nodes** self-configure via Cloud-Init
   - No SSH required (scales automatically with VMSS)
   - Installs Nomad Client + Docker
   - Connects to servers via Load Balancer
5. **Cluster ready** for job deployment

### Multi-Environment Strategy

**Terraform Workspaces**: Separate state per environment (`dev`, `stg`, `prd`)
- Each workspace has its own:
  - Resource Group: `rg-nomad-cluster-{env}`
  - Managed Identity: `id-nomad-{env}`
  - GitHub Environment: `{env}`
  - OIDC Federated Credential

### Authentication Pattern

**OIDC Federated Identity** (passwordless):
```
GitHub Actions → Azure AD Token Exchange → Managed Identity → Azure Resources
```
- No secrets stored in GitHub
- Short-lived tokens (automatic rotation)
- Scoped to specific environment/workflow

### Key Technical Decisions

1. **Nomad over Kubernetes**: Lower complexity, simpler operations
2. **Terraform Workspaces**: Multi-environment support without code duplication
3. **OIDC Authentication**: Eliminate long-lived credentials
4. **Cloud-Init for Clients**: Auto-scaling without Ansible dependency
5. **Co-located Consul**: Reduces VM count, sufficient for dev/test
6. **VMSS for Clients**: Automatic scaling and VM replacement
7. **Azure Bastion**: Secure SSH access (no public IPs on VMs)

### Access Points

- **Nomad UI**: `http://<LB_IP>:4646/ui`
- **Consul UI**: `http://<LB_IP>:8500/ui`
- **CLI**: `export NOMAD_ADDR=http://<LB_IP>:4646 && nomad status`
- **SSH Servers**: NAT via Load Balancer ports 50001-50003

### Important Files for Agents

| Task | Key Files |
|------|-----------|
| **Infrastructure changes** | `terraform/modules/**/*.tf` |
| **Server configuration** | `ansible/playbooks/*.yml`, `ansible/templates/*.j2` |
| **Client provisioning** | `terraform/modules/compute/templates/nomad-client-cloud-init.yaml.tftpl` |
| **CI/CD modifications** | `.github/workflows/*.yml` |
| **Network changes** | `terraform/modules/network/main.tf` |
| **Job deployment** | `jobs/*.nomad` |

### Common Operations

```bash
# Deploy infrastructure (via GitHub Actions)
# Actions → Provision Nomad Cluster → Run workflow → Select env/action

# SSH to server
ssh -p 50001 azureuser@<LB_IP> -i ~/.ssh/nomad-key

# Deploy Nomad job
nomad job run jobs/example.nomad

# Check cluster status
nomad server members
nomad node status

# Scale clients (modify VMSS)
terraform workspace select dev
terraform apply -var client_count=5
```

### Constraints & Limitations

- **Single Region**: No multi-region HA
- **No Disaster Recovery**: Manual recovery via Terraform redeploy
- **Public Load Balancer**: UI/API exposed (NSG-protected)
- **Cloud-Init only for Clients**: Server nodes require Ansible
- **Simplified Dev/Test**: Production requires additional hardening (see `docs/security.md`)

### Environment Variables (GitHub Secrets)

Per environment (`dev`, `stg`, `prd`):
- `AZURE_CLIENT_ID`: Managed Identity Client ID
- `AZURE_TENANT_ID`: Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID

### Monitoring & Logging

- **Log Analytics Workspace**: Centralized logging
- **Azure Monitor**: VM metrics
- **Health Probes**: Load Balancer checks Nomad/Consul leader endpoints

---

## Quick Reference

### Start Here (New Agents)
1. Read: `README.md` (project overview)
2. Read: `docs/architecture-simple.md` (simplified architecture)
3. Review: `.github/workflows/provision-cluster.yml` (deployment pipeline)
4. Check: `terraform/main.tf` (infrastructure root)

### Modify Infrastructure
- **Network**: `terraform/modules/network/`
- **VMs**: `terraform/modules/compute/`
- **Services**: `terraform/modules/services/`

### Change Configuration
- **Server setup**: `ansible/playbooks/nomad-server.yml`
- **Client setup**: `terraform/modules/compute/templates/nomad-client-cloud-init.yaml.tftpl`
- **Consul**: `ansible/playbooks/consul.yml`

### Deploy Applications
- **Job files**: `jobs/*.nomad`
- **App code**: `app/` (example Flask app)
- **Pipeline**: `.github/workflows/deploy-app.yml`

### Troubleshooting
- **Logs**: Check GitHub Actions logs, Azure Portal VM diagnostics
- **SSH Access**: Use NAT ports 50001-50003 or Azure Bastion
- **State Issues**: Terraform state in Azure Storage `tfstatenomadcluster`

---

**Last Updated**: 2025-01-10
**Project Type**: Infrastructure as Code + DevOps Automation
**Primary Language**: HCL (Terraform), YAML (Ansible/GHA), Python (Demo App)
