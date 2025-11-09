provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Aktuelle Client-Konfiguration
data "azurerm_client_config" "current" {}

# Workspace-Name für Ressourcen-Benennung
locals {
  workspace = terraform.workspace
  env_prefix = "${var.prefix}-${local.workspace}"
}

# Resource Group
resource "azurerm_resource_group" "nomad" {
  name     = "rg-nomad-cluster-${local.workspace}"
  location = var.location
  tags     = merge(var.tags, {
    Workspace = local.workspace
  })
}

# Network Module
module "network" {
  source = "./modules/network"
  
  prefix              = local.env_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.nomad.name
  allowed_ssh_ips     = var.allowed_ssh_ips
  tags                = merge(var.tags, { Workspace = local.workspace })
}

# Services Module (Key Vault, Log Analytics, ACR)
module "services" {
  source = "./modules/services"
  
  prefix                      = local.env_prefix
  location                    = var.location
  resource_group_name         = azurerm_resource_group.nomad.name
  enable_github_actions_rbac  = var.enable_github_actions_rbac
  tags                        = merge(var.tags, { Workspace = local.workspace })
}

# SSH Module
module "ssh" {
  source = "./modules/ssh"
  
  prefix          = local.env_prefix
  key_vault_id    = module.services.key_vault_id
  tags            = merge(var.tags, { Workspace = local.workspace })
  save_local_keys = true
  
  depends_on = [module.services]
}

# Compute Module (VMs und VMSS)
module "compute" {
  source = "./modules/compute"
  
  prefix              = local.env_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.nomad.name
  subnet_id           = module.network.cluster_subnet_id
  server_nsg_id       = module.network.server_nsg_id
  client_nsg_id       = module.network.client_nsg_id
  
  server_count     = var.server_count
  client_count     = var.client_count
  client_min_count = var.client_min_count
  client_max_count = var.client_max_count
  server_vm_size   = var.server_vm_size
  client_vm_size   = var.client_vm_size
  
  admin_ssh_key = module.ssh.public_key
  
  datacenter     = var.datacenter
  nomad_version  = var.nomad_version
  consul_version = var.consul_version
  
  tags = merge(var.tags, { Workspace = local.workspace })
  
  depends_on = [module.ssh]
}
