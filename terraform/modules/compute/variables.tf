variable "prefix" {
  description = "Prefix für alle Ressourcen"
  type        = string
}

variable "location" {
  description = "Azure Region für alle Ressourcen"
  type        = string
}

variable "resource_group_name" {
  description = "Name der Resource Group"
  type        = string
}

variable "tags" {
  description = "Tags für alle Ressourcen"
  type        = map(string)
}

variable "server_count" {
  description = "Anzahl der Nomad Server Nodes"
  type        = number
}

variable "client_count" {
  description = "Initiale Anzahl der Nomad Client Nodes"
  type        = number
}

variable "client_min_count" {
  description = "Minimale Anzahl der Nomad Client Nodes (für Auto-Scaling)"
  type        = number
}

variable "client_max_count" {
  description = "Maximale Anzahl der Nomad Client Nodes (für Auto-Scaling)"
  type        = number
}

variable "server_vm_size" {
  description = "VM Größe für Nomad Server"
  type        = string
}

variable "client_vm_size" {
  description = "VM Größe für Nomad Clients"
  type        = string
}

variable "admin_ssh_key" {
  description = "SSH Public Key für VM-Zugriff"
  type        = string
}

variable "subnet_id" {
  description = "ID des Subnets für die VMs"
  type        = string
}

variable "server_nsg_id" {
  description = "ID der Network Security Group für Server"
  type        = string
}

variable "client_nsg_id" {
  description = "ID der Network Security Group für Clients"
  type        = string
}

variable "datacenter" {
  description = "Nomad Datacenter Name"
  type        = string
}

variable "nomad_version" {
  description = "Nomad Version"
  type        = string
}

variable "consul_version" {
  description = "Consul Version"
  type        = string
}

variable "consul_encrypt" {
  description = "Consul Gossip Encryption Key (output of 'consul keygen')"
  type        = string
  sensitive   = true
}

variable "acr_id" {
  description = "ID der Azure Container Registry"
  type        = string
}

variable "acr_login_server" {
  description = "Login Server der Azure Container Registry"
  type        = string
}

variable "acr_admin_username" {
  description = "Admin Username der Azure Container Registry"
  type        = string
  sensitive   = true
}

variable "acr_admin_password" {
  description = "Admin Password der Azure Container Registry"
  type        = string
  sensitive   = true
}
