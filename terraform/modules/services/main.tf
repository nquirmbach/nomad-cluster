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
