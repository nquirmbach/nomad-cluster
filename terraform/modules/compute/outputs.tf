output "nomad_server_ids" {
  description = "IDs der Nomad Server VMs"
  value       = azurerm_linux_virtual_machine.nomad_server[*].id
}

output "nomad_server_names" {
  description = "Namen der Nomad Server VMs"
  value       = azurerm_linux_virtual_machine.nomad_server[*].name
}

output "nomad_server_private_ips" {
  description = "Private IPs der Nomad Server"
  value       = [for nic in azurerm_network_interface.nomad_server : nic.private_ip_address]
}

output "load_balancer_public_ip" {
  description = "Public IP des Load Balancers"
  value       = azurerm_public_ip.lb.ip_address
}

output "ssh_ports" {
  description = "SSH Ports für jeden Server (via Load Balancer NAT)"
  value       = [for i in range(var.server_count) : 50001 + i]
}

output "nomad_client_vmss_id" {
  description = "ID der Nomad Client VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.nomad_client.id
}


locals {
  inventory = <<-EOT
[nomad_servers]
%{for i in range(length(azurerm_linux_virtual_machine.nomad_server))~}
${azurerm_linux_virtual_machine.nomad_server[i].name} ansible_host=${azurerm_public_ip.lb.ip_address} ansible_port=${50001 + i}
%{endfor~}

[nomad_clients]
# Clients werden via Cloud-Init konfiguriert

[bastion]
${azurerm_linux_virtual_machine.bastion.name} ansible_host=${azurerm_public_ip.bastion.ip_address}

[all:vars]
ansible_user=azureuser
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
datacenter=${var.datacenter}
nomad_version=${var.nomad_version}
consul_version=${var.consul_version}
EOT
}

output "ansible_inventory" {
  description = "Ansible Inventory für Nomad Cluster"
  value       = local.inventory
}

output "bastion_public_ip" {
  description = "Public IP des Bastion Hosts"
  value       = azurerm_public_ip.bastion.ip_address
}

output "bastion_private_ip" {
  description = "Private IP des Bastion Hosts"
  value       = azurerm_network_interface.bastion.private_ip_address
}

output "bastion_fqdn" {
  description = "FQDN des Bastion Hosts"
  value       = azurerm_public_ip.bastion.fqdn
}
