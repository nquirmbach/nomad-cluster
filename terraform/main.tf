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

# Resource Group (created by setup script)
data "azurerm_resource_group" "rg" {
  name = "rg-nomad-cluster-${local.workspace}"
}

# Network Module
module "network" {
  source = "./modules/network"
  
  prefix              = local.env_prefix
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allowed_ssh_ips     = var.allowed_ssh_ips
  tags                = merge(var.tags, { Workspace = local.workspace })
}

# Services Module (Key Vault, Log Analytics, ACR)
module "services" {
  source = "./modules/services"
  
  prefix                      = local.env_prefix
  location                    = data.azurerm_resource_group.rg.location
  resource_group_name         = data.azurerm_resource_group.rg.name
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
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = module.network.cluster_subnet_id
  server_nsg_id       = module.network.server_nsg_id
  client_nsg_id       = module.network.client_nsg_id
  bastion_subnet_id   = module.network.bastion_subnet_id
  bastion_nsg_id      = module.network.bastion_nsg_id
  
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
  acr_id         = module.services.acr_id
  acr_login_server    = module.services.acr_login_server
  acr_admin_username  = module.services.acr_admin_username
  acr_admin_password  = module.services.acr_admin_password
  
  tags = merge(var.tags, { Workspace = local.workspace })
  
  depends_on = [module.ssh]
}
