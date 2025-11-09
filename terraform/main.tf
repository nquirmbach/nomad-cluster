provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

terraform {
  backend "azurerm" {
    # Backend-Konfiguration wird über CLI-Parameter übergeben
  }
}

# Resource Group
resource "azurerm_resource_group" "nomad" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "nomad" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  tags                = var.tags
}

# Subnet
resource "azurerm_subnet" "cluster" {
  name                 = "${var.prefix}-cluster-subnet"
  resource_group_name  = azurerm_resource_group.nomad.name
  virtual_network_name = azurerm_virtual_network.nomad.name
  address_prefixes     = ["10.0.10.0/24"]
}

# Network Security Group für Nomad Server
resource "azurerm_network_security_group" "nomad_server" {
  name                = "${var.prefix}-server-nsg"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  tags                = var.tags

  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
  }

  # Nomad HTTP API
  security_rule {
    name                       = "NomadHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4646"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Nomad RPC
  security_rule {
    name                       = "NomadRPC"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4647"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Nomad Serf WAN
  security_rule {
    name                       = "NomadSerf"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "4648"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Consul HTTP API
  security_rule {
    name                       = "ConsulHTTP"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Consul Server RPC
  security_rule {
    name                       = "ConsulRPC"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8300"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Consul Serf LAN
  security_rule {
    name                       = "ConsulSerfLAN"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8301"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Network Security Group für Nomad Clients
resource "azurerm_network_security_group" "nomad_client" {
  name                = "${var.prefix}-client-nsg"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  tags                = var.tags

  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
  }

  # Nomad HTTP API
  security_rule {
    name                       = "NomadHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4646"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Nomad RPC
  security_rule {
    name                       = "NomadRPC"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4647"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Nomad Serf WAN
  security_rule {
    name                       = "NomadSerf"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "4648"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Dynamic Ports für Nomad Allocations (30000-32000)
  security_rule {
    name                       = "NomadDynamicPorts"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "30000-32000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Key Vault
resource "azurerm_key_vault" "nomad" {
  name                        = "${var.prefix}-kv"
  location                    = azurerm_resource_group.nomad.location
  resource_group_name         = azurerm_resource_group.nomad.name
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
      "Get", "List", "Create", "Delete", "Update",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete",
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete",
    ]
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "nomad" {
  name                = "${var.prefix}-logs"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = replace("${var.prefix}acr", "-", "")
  resource_group_name = azurerm_resource_group.nomad.name
  location            = azurerm_resource_group.nomad.location
  sku                 = "Standard"
  admin_enabled       = true
  tags                = var.tags
}

# Aktuelle Client-Konfiguration für Key Vault Access Policy
data "azurerm_client_config" "current" {}

# Verzeichnis für SSH-Schlüssel erstellen
resource "local_file" "ssh_directory" {
  content  = ""
  filename = "${path.root}/ssh_keys/.gitkeep"

  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/ssh_keys"
  }
}

# SSH-Modul für die Schlüsselgenerierung
module "ssh" {
  source = "./modules/ssh"
  
  prefix       = var.prefix
  key_vault_id = azurerm_key_vault.nomad.id
  tags         = var.tags
  
  # Optional: Speichere Schlüssel lokal für einfachen Zugriff
  save_local_keys = true
  
  depends_on = [local_file.ssh_directory]
}

# Nomad Server VMs
resource "azurerm_linux_virtual_machine" "nomad_server" {
  count                 = var.server_count
  name                  = "${var.prefix}-server-${count.index + 1}"
  location              = azurerm_resource_group.nomad.location
  resource_group_name   = azurerm_resource_group.nomad.name
  network_interface_ids = [azurerm_network_interface.nomad_server[count.index].id]
  size                  = var.server_vm_size
  admin_username        = "azureuser"
  tags                  = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = module.ssh.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# Nomad Server NICs
resource "azurerm_network_interface" "nomad_server" {
  count               = var.server_count
  name                = "${var.prefix}-server-nic-${count.index + 1}"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cluster.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nomad_server[count.index].id
  }
}

# Nomad Server Public IPs
resource "azurerm_public_ip" "nomad_server" {
  count               = var.server_count
  name                = "${var.prefix}-server-ip-${count.index + 1}"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  allocation_method   = "Static"
  tags                = var.tags
}

# NSG Association für Server NICs
resource "azurerm_network_interface_security_group_association" "nomad_server" {
  count                     = var.server_count
  network_interface_id      = azurerm_network_interface.nomad_server[count.index].id
  network_security_group_id = azurerm_network_security_group.nomad_server.id
}

# Nomad Client VMSS
resource "azurerm_linux_virtual_machine_scale_set" "nomad_client" {
  name                = "${var.prefix}-client-vmss"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  sku                 = var.client_vm_size
  instances           = var.client_count
  admin_username      = "azureuser"
  tags                = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = module.ssh.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  network_interface {
    name    = "client-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.cluster.id
      public_ip_address {
        name              = "client-public-ip"
        public_ip_prefix_id = azurerm_public_ip_prefix.client.id
      }
    }

    network_security_group_id = azurerm_network_security_group.nomad_client.id
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# Public IP Prefix für Client VMSS
resource "azurerm_public_ip_prefix" "client" {
  name                = "${var.prefix}-client-ip-prefix"
  location            = azurerm_resource_group.nomad.location
  resource_group_name = azurerm_resource_group.nomad.name
  prefix_length       = 28
  tags                = var.tags
}

# Auto-Scaling für Client VMSS
resource "azurerm_monitor_autoscale_setting" "nomad_client" {
  name                = "${var.prefix}-client-autoscale"
  resource_group_name = azurerm_resource_group.nomad.name
  location            = azurerm_resource_group.nomad.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.nomad_client.id
  tags                = var.tags

  profile {
    name = "DefaultProfile"

    capacity {
      default = var.client_count
      minimum = var.client_min_count
      maximum = var.client_max_count
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.nomad_client.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.nomad_client.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

# VM Insights für Monitoring
resource "azurerm_virtual_machine_scale_set_extension" "client_monitoring" {
  name                         = "VMInsights"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.nomad_client.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
}

resource "azurerm_virtual_machine_extension" "server_monitoring" {
  count                = var.server_count
  name                 = "VMInsights"
  virtual_machine_id   = azurerm_linux_virtual_machine.nomad_server[count.index].id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}

# Ansible Inventory generieren
# Hinweis: VMSS-Clients werden dynamisch zur Laufzeit über Azure CLI abgefragt
# da ihre IPs erst nach dem Deployment verfügbar sind
locals {
  inventory = <<-EOT
[nomad_servers]
%{for i in range(var.server_count)~}
${azurerm_linux_virtual_machine.nomad_server[i].name} ansible_host=${azurerm_public_ip.nomad_server[i].ip_address}
%{endfor~}

[nomad_clients]
# VMSS-Instanzen werden zur Laufzeit hinzugefügt
# Verwenden Sie: az vmss list-instance-public-ips -g ${azurerm_resource_group.nomad.name} -n ${azurerm_linux_virtual_machine_scale_set.nomad_client.name}

[all:vars]
ansible_user=azureuser
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
datacenter=${var.datacenter}
nomad_version=${var.nomad_version}
consul_version=${var.consul_version}
EOT
}
