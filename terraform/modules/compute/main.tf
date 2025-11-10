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

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "nomad_servers" {
  name            = "${var.prefix}-backend-pool"
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

# Nomad Client VMSS
resource "azurerm_linux_virtual_machine_scale_set" "nomad_client" {
  name                = "${var.prefix}-client-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.client_vm_size
  instances           = var.client_count
  admin_username      = "azureuser"
  tags                = var.tags

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
      name      = "internal"
      primary   = true
      subnet_id = var.subnet_id
    }

    network_security_group_id = var.client_nsg_id
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  # Cloud-Init für Client-Konfiguration
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - unzip
      - wget
      - curl
      - jq
      - apt-transport-https
      - ca-certificates
      - gnupg
      - docker.io

    write_files:
      - path: /etc/nomad.d/client.hcl
        content: |
          data_dir  = "/opt/nomad/data"
          bind_addr = "0.0.0.0"
          
          client {
            enabled = true
            servers = [
              "${azurerm_linux_virtual_machine.nomad_server[0].private_ip_address}:4647",
              "${azurerm_linux_virtual_machine.nomad_server[1].private_ip_address}:4647",
              "${azurerm_linux_virtual_machine.nomad_server[2].private_ip_address}:4647"
            ]
            network_interface = "eth0"
          }
          
          plugin "docker" {
            config {
              allow_privileged = true
              volumes {
                enabled = true
              }
              extra_labels = ["job_name", "job_id", "task_group", "task_name", "namespace", "node_name"]
            }
          }
          
          datacenter = "${var.datacenter}"
          region     = "global"
          
          log_level = "INFO"
          log_file  = "/var/log/nomad.log"
          
          telemetry {
            publish_allocation_metrics = true
            publish_node_metrics = true
            prometheus_metrics = true
          }
        
      - path: /etc/systemd/system/nomad-client.service
        content: |
          [Unit]
          Description=Nomad Client
          Documentation=https://nomadproject.io/docs/
          Wants=network-online.target
          After=network-online.target

          [Service]
          ExecReload=/bin/kill -HUP $MAINPID
          ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
          KillMode=process
          KillSignal=SIGINT
          LimitNOFILE=65536
          LimitNPROC=infinity
          Restart=on-failure
          RestartSec=2
          StartLimitBurst=3
          StartLimitIntervalSec=10
          TasksMax=infinity

          [Install]
          WantedBy=multi-user.target

    runcmd:
      - mkdir -p /opt/nomad/data /etc/nomad.d /var/log
      - echo "Downloading Nomad ${var.nomad_version}..."
      - wget -q https://releases.hashicorp.com/nomad/${var.nomad_version}/nomad_${var.nomad_version}_linux_amd64.zip -O /tmp/nomad.zip
      - unzip /tmp/nomad.zip -d /usr/local/bin
      - chmod +x /usr/local/bin/nomad
      - rm /tmp/nomad.zip
      - echo "Creating nomad user..."
      - useradd --system --home /etc/nomad.d --shell /bin/false nomad
      - chown -R nomad:nomad /opt/nomad /etc/nomad.d /var/log/nomad.log
      - echo "Configuring Docker..."
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ubuntu
      - echo "Configuring Docker daemon..."
      - mkdir -p /etc/docker
      - echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' > /etc/docker/daemon.json
      - systemctl restart docker
      - echo "Logging into ACR with admin credentials..."
      - docker login ${var.acr_login_server} -u ${var.acr_admin_username} -p ${var.acr_admin_password}
      - echo "Enabling and starting Nomad client..."
      - systemctl daemon-reload
      - systemctl enable nomad-client
      - systemctl start nomad-client
      - echo "Nomad client setup completed!"
  EOF
  )
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

# Bastion Host Public IP
resource "azurerm_public_ip" "bastion" {
  name                = "${var.prefix}-bastion-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Bastion Host NIC
resource "azurerm_network_interface" "bastion" {
  name                = "${var.prefix}-bastion-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.bastion_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

# NSG Association für Bastion NIC
resource "azurerm_network_interface_security_group_association" "bastion" {
  network_interface_id      = azurerm_network_interface.bastion.id
  network_security_group_id = var.bastion_nsg_id
}

# Bastion Host VM
resource "azurerm_linux_virtual_machine" "bastion" {
  name                  = "${var.prefix}-bastion"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.bastion.id]
  size                  = var.bastion_vm_size
  admin_username        = "azureuser"
  tags                  = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
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

  # Cloud-Init für Bastion-Konfiguration
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - unzip
      - wget
      - curl
      - jq
      - tmux
      - htop
      - sshpass

    write_files:
      - path: /etc/motd
        content: |
          *************************************************************
          *                                                           *
          *                     BASTION HOST                          *
          *                                                           *
          * This system is for authorized users only.                 *
          * All connections are monitored and recorded.               *
          *                                                           *
          *************************************************************

    runcmd:
      - echo "Bastion host setup completed!"
  EOF
  )
}

# VM Insights für Bastion Monitoring
resource "azurerm_virtual_machine_extension" "bastion_monitoring" {
  name                 = "VMInsights"
  virtual_machine_id   = azurerm_linux_virtual_machine.bastion.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}
