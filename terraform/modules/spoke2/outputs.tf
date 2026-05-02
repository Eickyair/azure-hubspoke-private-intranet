output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "mysql_app_fqdn" {
  value = azurerm_mysql_flexible_server.app.fqdn
}

output "mysql_admin_fqdn" {
  value = azurerm_mysql_flexible_server.admin.fqdn
}

output "mysql_app_database_name" {
  value = azurerm_mysql_flexible_database.app.name
}

output "mysql_admin_database_name" {
  value = azurerm_mysql_flexible_database.admin.name
}

output "storage_account_name" {
  value = azurerm_storage_account.documents.name
}

output "storage_primary_blob_endpoint" {
  value = azurerm_storage_account.documents.primary_blob_endpoint
}

output "storage_primary_access_key" {
  value     = azurerm_storage_account.documents.primary_access_key
  sensitive = true
}

output "storage_container_name" {
  value = azurerm_storage_container.documents.name
}
