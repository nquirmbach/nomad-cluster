output "vnet_id" {
  description = "ID des Virtual Networks"
  value       = azurerm_virtual_network.nomad.id
}

output "vnet_name" {
  description = "Name des Virtual Networks"
  value       = azurerm_virtual_network.nomad.name
}

output "cluster_subnet_id" {
  description = "ID des Cluster Subnets"
  value       = azurerm_subnet.cluster.id
}

output "server_nsg_id" {
  description = "ID der Server Network Security Group"
  value       = azurerm_network_security_group.nomad_server.id
}

output "client_nsg_id" {
  description = "ID der Client Network Security Group"
  value       = azurerm_network_security_group.nomad_client.id
}

output "bastion_subnet_id" {
  description = "ID des Bastion Subnets"
  value       = azurerm_subnet.bastion.id
}

output "bastion_nsg_id" {
  description = "ID der Bastion Network Security Group"
  value       = azurerm_network_security_group.bastion.id
}
