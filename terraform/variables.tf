variable "prefix" {
  description = "Prefix für alle Ressourcen"
  type        = string
  default     = "nomad"
}

variable "location" {
  description = "Azure Region für alle Ressourcen"
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags für alle Ressourcen"
  type        = map(string)
  default = {
    Environment = "Dev"
    Project     = "NomadCluster"
    ManagedBy   = "Terraform"
  }
}

variable "server_count" {
  description = "Anzahl der Nomad Server Nodes"
  type        = number
  default     = 3
}

variable "client_count" {
  description = "Initiale Anzahl der Nomad Client Nodes"
  type        = number
  default     = 2
}

variable "client_min_count" {
  description = "Minimale Anzahl der Nomad Client Nodes (für Auto-Scaling)"
  type        = number
  default     = 2
}

variable "client_max_count" {
  description = "Maximale Anzahl der Nomad Client Nodes (für Auto-Scaling)"
  type        = number
  default     = 10
}

variable "server_vm_size" {
  description = "VM Größe für Nomad Server"
  type        = string
  default     = "Standard_B2s"
}

variable "client_vm_size" {
  description = "VM Größe für Nomad Clients"
  type        = string
  default     = "Standard_B2ms"
}

# SSH-Schlüssel werden automatisch generiert und in Key Vault gespeichert

variable "enable_github_actions_rbac" {
  description = "Aktiviert RBAC-Zuweisungen für GitHub Actions Managed Identity (muss vorher über setup-federated-identity.sh erstellt werden)"
  type        = bool
  default     = false
}

variable "allowed_ssh_ips" {
  description = "Liste der erlaubten IPs für SSH-Zugriff"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Für Production einschränken!
}

variable "datacenter" {
  description = "Nomad Datacenter Name"
  type        = string
  default     = "dc1"
}

variable "nomad_version" {
  description = "Nomad Version"
  type        = string
  default     = "1.6.0"
}

variable "consul_version" {
  description = "Consul Version"
  type        = string
  default     = "1.16.0"
}
