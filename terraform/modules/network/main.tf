resource "azurerm_virtual_network" "nomad" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "cluster" {
  name                 = "${var.prefix}-cluster-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.nomad.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.nomad.name
  address_prefixes     = ["10.0.20.0/27"]
}

resource "azurerm_network_security_group" "nomad_server" {
  name                = "${var.prefix}-server-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
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

resource "azurerm_network_security_group" "nomad_client" {
  name                = "${var.prefix}-client-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # SSH von Azure Bastion Service
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.20.0/27" # AzureBastionSubnet
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

# Public IP für Azure Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "${var.prefix}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Bastion Service
resource "azurerm_bastion_host" "nomad" {
  name                = "${var.prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
