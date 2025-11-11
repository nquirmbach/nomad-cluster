# Key Vault
resource "azurerm_key_vault" "nomad" {
  name                        = "${var.prefix}-kv"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  tags                        = var.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Purge", "Recover"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Purge", "Recover"
    ]
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "nomad" {
  name                = "${var.prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = replace("${var.prefix}acr", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true
  tags                = var.tags
}

# Aktuelle Client-Konfiguration für Key Vault Access Policy
data "azurerm_client_config" "current" {}

# GitHub Actions Managed Identity (falls vorhanden)
data "azurerm_user_assigned_identity" "github_actions" {
  count               = var.enable_github_actions_rbac ? 1 : 0
  name                = "${var.prefix}-github-actions-identity"
  resource_group_name = var.resource_group_name
}

# RBAC für GitHub Actions Managed Identity auf ACR
resource "azurerm_role_assignment" "github_actions_acr_push" {
  count                = var.enable_github_actions_rbac ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.github_actions[0].principal_id
}

# Consul Encryption Key generieren (base64-kodierter 32-Byte-Schlüssel)
resource "random_id" "consul_encrypt" {
  byte_length = 32
}

# Consul-Verschlüsselungsschlüssel im Key Vault speichern
resource "azurerm_key_vault_secret" "consul_encrypt" {
  name         = "consul-encrypt-key"
  value        = random_id.consul_encrypt.b64_std
  key_vault_id = azurerm_key_vault.nomad.id
}

# Azure Storage Account for artifacts
resource "azurerm_storage_account" "artifacts" {
  name                            = replace("${var.prefix}storage", "-", "")
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true
  # Public access is controlled at the container level
  tags                            = var.tags
}

# Create artifacts container
resource "azurerm_storage_container" "artifacts" {
  name                  = "artifacts"
  storage_account_id    = azurerm_storage_account.artifacts.id
  container_access_type = "blob"
}

# RBAC for GitHub Actions Managed Identity on Storage Account
resource "azurerm_role_assignment" "github_actions_storage_contributor" {
  count                = var.enable_github_actions_rbac ? 1 : 0
  scope                = azurerm_storage_account.artifacts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.github_actions[0].principal_id
}
