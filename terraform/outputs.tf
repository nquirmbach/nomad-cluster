# Network Outputs
output "vnet_id" {
  description = "ID des Virtual Networks"
  value       = module.network.vnet_id
}

output "cluster_subnet_id" {
  description = "ID des Cluster Subnets"
  value       = module.network.cluster_subnet_id
}

# Compute Outputs
output "load_balancer_public_ip" {
  description = "Öffentliche IP-Adresse des Load Balancers"
  value       = module.compute.load_balancer_public_ip
}

output "ssh_connection_info" {
  description = "SSH Verbindungsinformationen für Server"
  value = {
    for i in range(length(module.compute.ssh_ports)) :
    "server-${i + 1}" => {
      host = module.compute.load_balancer_public_ip
      port = module.compute.ssh_ports[i]
    }
  }
}

output "nomad_server_private_ips" {
  description = "Private IP-Adressen der Nomad Server"
  value       = module.compute.nomad_server_private_ips
}

output "nomad_client_vmss_id" {
  description = "ID des Nomad Client VMSS"
  value       = module.compute.nomad_client_vmss_id
}

# Services Outputs
output "key_vault_id" {
  description = "ID des Key Vaults"
  value       = module.services.key_vault_id
}

output "key_vault_name" {
  description = "Name des Key Vaults"
  value       = module.services.key_vault_name
}

output "log_analytics_workspace_id" {
  description = "ID des Log Analytics Workspace"
  value       = module.services.log_analytics_workspace_id
}

output "acr_id" {
  description = "ID der Azure Container Registry"
  value       = module.services.acr_id
}

output "acr_name" {
  description = "Name der Azure Container Registry"
  value       = module.services.acr_name
}

output "acr_login_server" {
  description = "Login Server der Azure Container Registry"
  value       = module.services.acr_login_server
}

# SSH Outputs
output "ssh_public_key" {
  description = "Der generierte öffentliche SSH-Schlüssel"
  value       = module.ssh.public_key
}

output "ssh_private_key" {
  description = "Der generierte private SSH-Schlüssel"
  value       = module.ssh.private_key
  sensitive   = true
}

output "ssh_private_key_secret_name" {
  description = "Name des Key Vault Secrets für den privaten SSH-Schlüssel"
  value       = module.ssh.ssh_private_key_secret_name
}

output "ssh_public_key_secret_name" {
  description = "Name des Key Vault Secrets für den öffentlichen SSH-Schlüssel"
  value       = module.ssh.ssh_public_key_secret_name
}

# Resource Group Output
output "resource_group_name" {
  description = "Name der Resource Group"
  value       = data.azurerm_resource_group.rg.name
}

# Ansible Inventory
output "ansible_inventory" {
  description = "Ansible Inventory für Nomad Cluster"
  value       = module.compute.ansible_inventory
}

# Azure Bastion Service Outputs
output "azure_bastion_public_ip" {
  description = "Public IP des Azure Bastion Services"
  value       = module.network.azure_bastion_public_ip
}

output "azure_bastion_host_id" {
  description = "ID des Azure Bastion Hosts"
  value       = module.network.azure_bastion_host_id
}

output "azure_bastion_access_info" {
  description = "Information zum Zugriff auf VMs über Azure Bastion"
  value       = "Zugriff auf VMs über Azure Portal > Virtual Machines > Connect > Bastion"
}

# Consul Encrypt Key Output
output "consul_encrypt" {
  description = "Consul Gossip Encryption Key"
  value       = module.services.consul_encrypt
  sensitive   = true
}
