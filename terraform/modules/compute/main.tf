# Nomad Server VMs
resource "azurerm_linux_virtual_machine" "nomad_server" {
  count                 = var.server_count
  name                  = "${var.prefix}-server-${count.index + 1}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nomad_server[count.index].id]
  size                  = var.server_vm_size
  admin_username        = "azureuser"
  tags                  = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_key
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
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# Load Balancer Public IP
resource "azurerm_public_ip" "lb" {
  name                = "${var.prefix}-lb-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Load Balancer
resource "azurerm_lb" "nomad" {
  name                = "${var.prefix}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# Backend Address Pool für Server
resource "azurerm_lb_backend_address_pool" "nomad_servers" {
  name            = "${var.prefix}-server-backend-pool"
  loadbalancer_id = azurerm_lb.nomad.id
}

# Backend Address Pool für Clients
resource "azurerm_lb_backend_address_pool" "nomad_clients" {
  name            = "${var.prefix}-client-backend-pool"
  loadbalancer_id = azurerm_lb.nomad.id
}

# Health Probe für Nomad API
resource "azurerm_lb_probe" "nomad_api" {
  name            = "nomad-api-probe"
  loadbalancer_id = azurerm_lb.nomad.id
  protocol        = "Http"
  port            = 4646
  request_path    = "/v1/status/leader"
}

# Load Balancer Rule für Nomad UI/API
resource "azurerm_lb_rule" "nomad_ui" {
  name                           = "nomad-ui"
  loadbalancer_id                = azurerm_lb.nomad.id
  protocol                       = "Tcp"
  frontend_port                  = 4646
  backend_port                   = 4646
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nomad_servers.id]
  probe_id                       = azurerm_lb_probe.nomad_api.id
}

# Health Probe für Consul
resource "azurerm_lb_probe" "consul" {
  name            = "consul-probe"
  loadbalancer_id = azurerm_lb.nomad.id
  protocol        = "Http"
  port            = 8500
  request_path    = "/v1/status/leader"
}

# Load Balancer Rule für Consul UI
resource "azurerm_lb_rule" "consul_ui" {
  name                           = "consul-ui"
  loadbalancer_id                = azurerm_lb.nomad.id
  protocol                       = "Tcp"
  frontend_port                  = 8500
  backend_port                   = 8500
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nomad_servers.id]
  probe_id                       = azurerm_lb_probe.consul.id
}

# Health Probe für Traefik HTTP
resource "azurerm_lb_probe" "traefik_http" {
  name            = "traefik-http-probe"
  loadbalancer_id = azurerm_lb.nomad.id
  protocol        = "Tcp"
  port            = 8080
}

# Load Balancer Rule für Traefik HTTP
resource "azurerm_lb_rule" "traefik_http" {
  name                           = "traefik-http"
  loadbalancer_id                = azurerm_lb.nomad.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nomad_clients.id]
  probe_id                       = azurerm_lb_probe.traefik_http.id
}

# Health Probe für Traefik Dashboard
resource "azurerm_lb_probe" "traefik_dashboard" {
  name            = "traefik-dashboard-probe"
  loadbalancer_id = azurerm_lb.nomad.id
  protocol        = "Tcp"
  port            = 8081
}

# Load Balancer Rule für Traefik Dashboard
resource "azurerm_lb_rule" "traefik_dashboard" {
  name                           = "traefik-dashboard"
  loadbalancer_id                = azurerm_lb.nomad.id
  protocol                       = "Tcp"
  frontend_port                  = 8081
  backend_port                   = 8081
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nomad_clients.id]
  probe_id                       = azurerm_lb_probe.traefik_dashboard.id
}

# Inbound NAT Rules für SSH (ein Port pro Server)
resource "azurerm_lb_nat_rule" "ssh" {
  count                          = var.server_count
  name                           = "ssh-server-${count.index + 1}"
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.nomad.id
  protocol                       = "Tcp"
  frontend_port                  = 50001 + count.index
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

# NSG Association für Server NICs
resource "azurerm_network_interface_security_group_association" "nomad_server" {
  count                     = var.server_count
  network_interface_id      = azurerm_network_interface.nomad_server[count.index].id
  network_security_group_id = var.server_nsg_id
}

# Backend Pool Association für Server NICs
resource "azurerm_network_interface_backend_address_pool_association" "nomad_server" {
  count                   = var.server_count
  network_interface_id    = azurerm_network_interface.nomad_server[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nomad_servers.id
}

# NAT Rule Association für SSH
resource "azurerm_network_interface_nat_rule_association" "ssh" {
  count                 = var.server_count
  network_interface_id  = azurerm_network_interface.nomad_server[count.index].id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.ssh[count.index].id
}

# VM Scale Set für Nomad Clients
resource "azurerm_linux_virtual_machine_scale_set" "nomad_client" {
  name                = "${var.prefix}-client-vmss"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.client_vm_size
  instances           = var.client_count
  admin_username      = "azureuser"
  tags                = var.tags
  upgrade_mode        = "Automatic"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_key
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
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.nomad_clients.id]
    }

    network_security_group_id = var.client_nsg_id
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  # Cloud-Init für Client-Konfiguration mit Template-Datei
  custom_data = base64encode(templatefile("${path.module}/templates/nomad-client-cloud-init.yaml.tftpl", {
    server_ips = [
      for s in azurerm_linux_virtual_machine.nomad_server : s.private_ip_address
    ],
    datacenter         = var.datacenter,
    nomad_version      = var.nomad_version,
    consul_version     = var.consul_version,
    consul_encrypt     = var.consul_encrypt,
    acr_login_server   = var.acr_login_server,
    acr_admin_username = var.acr_admin_username,
    acr_admin_password = var.acr_admin_password
  }))

  # Automatic rolling upgrade settings
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = true
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 20
    pause_time_between_batches              = "PT0S"
  }
}

# RBAC-Rolle für ACR Pull (Managed Identity)
resource "azurerm_role_assignment" "nomad_client_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine_scale_set.nomad_client.identity[0].principal_id
}

# Auto-Scaling für Client VMSS
resource "azurerm_monitor_autoscale_setting" "nomad_client" {
  name                = "${var.prefix}-client-autoscale"
  resource_group_name = var.resource_group_name
  location            = var.location
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

# Force VM Scale Set instance upgrade when backend pool association changes
resource "null_resource" "force_vmss_upgrade" {
  triggers = {
    vmss_id = azurerm_linux_virtual_machine_scale_set.nomad_client.id
    lb_backend_pool_id = azurerm_lb_backend_address_pool.nomad_clients.id
  }

  provisioner "local-exec" {
    command = "az vmss update-instances --resource-group ${var.resource_group_name} --name ${azurerm_linux_virtual_machine_scale_set.nomad_client.name} --instance-ids '*'"
  }

  depends_on = [
    azurerm_linux_virtual_machine_scale_set.nomad_client
  ]
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
  count                      = var.server_count
  name                       = "VMInsights"
  virtual_machine_id         = azurerm_linux_virtual_machine.nomad_server[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Bastion Host wurde durch Azure Bastion Service ersetzt
