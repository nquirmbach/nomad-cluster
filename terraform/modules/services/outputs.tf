output "key_vault_id" {
  description = "ID des Key Vaults"
  value       = azurerm_key_vault.nomad.id
}

output "key_vault_name" {
  description = "Name des Key Vaults"
  value       = azurerm_key_vault.nomad.name
}

output "log_analytics_workspace_id" {
  description = "ID des Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.nomad.id
}

output "acr_id" {
  description = "ID der Azure Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "Name der Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login Server der Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}
