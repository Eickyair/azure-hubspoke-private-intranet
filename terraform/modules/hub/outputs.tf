output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "private_dns_zone_ids" {
  value = { for key, zone in azurerm_private_dns_zone.shared : key => zone.id }
}

output "internal_dns_zone_id" {
  value = azurerm_private_dns_zone.internal.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "application_gateway_private_ip" {
  value = var.application_gateway.private_ip_address
}
