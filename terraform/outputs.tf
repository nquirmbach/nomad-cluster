output "resource_group_name" {
  description = "Name der Resource Group"
  value       = azurerm_resource_group.nomad.name
}

output "vnet_name" {
  description = "Name des Virtual Networks"
  value       = azurerm_virtual_network.nomad.name
}

output "nomad_server_names" {
  description = "Namen der Nomad Server VMs"
  value       = azurerm_linux_virtual_machine.nomad_server[*].name
}

output "nomad_server_private_ips" {
  description = "Private IPs der Nomad Server"
  value       = [for nic in azurerm_network_interface.nomad_server : nic.private_ip_address]
}

output "nomad_server_public_ips" {
  description = "Public IPs der Nomad Server"
  value       = azurerm_public_ip.nomad_server[*].ip_address
}

output "nomad_client_vmss_id" {
  description = "ID der Nomad Client VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.nomad_client.id
}

output "nomad_client_public_ips" {
  description = "Public IP Prefix für Nomad Clients"
  value       = azurerm_public_ip_prefix.client.ip_prefix
}

output "key_vault_name" {
  description = "Name des Key Vaults"
  value       = azurerm_key_vault.nomad.name
}

output "log_analytics_workspace_id" {
  description = "ID des Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.nomad.id
}

output "acr_login_server" {
  description = "Login Server der Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Admin Username der Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  description = "Admin Password der Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "ansible_inventory" {
  description = "Ansible Inventory für Nomad Cluster"
  value       = local.inventory
}

# SSH-Schlüssel Outputs
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
