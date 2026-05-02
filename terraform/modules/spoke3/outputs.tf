output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "mysql_analytics_fqdn" {
  value = azurerm_mysql_flexible_server.analytics.fqdn
}

output "mysql_analytics_database_name" {
  value = azurerm_mysql_flexible_database.analytics.name
}

output "private_ips" {
  value = {
    etl_runner = azurerm_network_interface.etl.private_ip_address
    dashboard  = azurerm_network_interface.dashboard.private_ip_address
  }
}
