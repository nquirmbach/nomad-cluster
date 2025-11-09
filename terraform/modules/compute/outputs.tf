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

output "nomad_server_public_ips" {
  description = "Public IPs der Nomad Server"
  value       = azurerm_public_ip.nomad_server[*].ip_address
}

output "nomad_client_vmss_id" {
  description = "ID der Nomad Client VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.nomad_client.id
}

output "client_ip_prefix" {
  description = "Public IP Prefix für Nomad Clients"
  value       = azurerm_public_ip_prefix.client.ip_prefix
}

# Diese Funktion generiert ein Ansible Inventory basierend auf den Server- und Client-VMs
locals {
  inventory = <<-EOT
[nomad_servers]
%{for i in range(length(azurerm_linux_virtual_machine.nomad_server))~}
${azurerm_linux_virtual_machine.nomad_server[i].name} ansible_host=${azurerm_public_ip.nomad_server[i].ip_address}
%{endfor~}

[nomad_clients]
%{for i in range(var.client_count)~}
${var.prefix}-client-${i} ansible_host=${azurerm_linux_virtual_machine_scale_set.nomad_client.id}
%{endfor~}

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
