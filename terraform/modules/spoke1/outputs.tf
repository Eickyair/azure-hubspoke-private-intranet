output "default_hostnames" {
  value = {
    webapp = azurerm_linux_web_app.webapp.default_hostname
    admin  = azurerm_linux_web_app.admin.default_hostname
    api    = azurerm_linux_web_app.api.default_hostname
  }
}

output "private_endpoint_private_ips" {
  value = {
    webapp = try(azurerm_private_endpoint.webapp.private_service_connection[0].private_ip_address, null)
    admin  = try(azurerm_private_endpoint.admin.private_service_connection[0].private_ip_address, null)
    api    = try(azurerm_private_endpoint.api.private_service_connection[0].private_ip_address, null)
  }
}
