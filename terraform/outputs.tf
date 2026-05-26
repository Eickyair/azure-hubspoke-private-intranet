output "resource_group_name" {
  description = "Resource Group unico de la solucion."
  value       = azurerm_resource_group.main.name
}

output "hub_vnet_id" {
  description = "ID de la VNet del Hub."
  value       = module.hub.vnet_id
}

output "private_dns_zone_ids" {
  description = "Zonas privadas compartidas creadas en el Hub."
  value       = module.hub.private_dns_zone_ids
}

output "spoke1_private_endpoints" {
  description = "Private Endpoints de App Service del Spoke 1."
  value       = module.spoke1.private_endpoint_private_ips
}

output "spoke1_default_hostnames" {
  description = "Hostnames default de Azure App Service para despliegue y diagnostico."
  value       = module.spoke1.default_hostnames
}

output "spoke2_mysql_fqdns" {
  description = "FQDN privados de MySQL operativos."
  value = {
    app   = module.spoke2.mysql_app_fqdn
    admin = module.spoke2.mysql_admin_fqdn
  }
}

output "spoke3_private_ips" {
  description = "IPs privadas de las VMs de analitica."
  value       = module.spoke3.private_ips
}

output "internal_urls" {
  description = "URLs internas previstas para la demo por VPN."
  value = {
    intranet  = "https://${var.internal_domains.intranet}"
    admin     = "https://${var.internal_domains.admin}"
    api       = "https://${var.internal_domains.api}/health"
    analytics = "https://${var.internal_domains.analytics}"
  }
}

output "jumpbox_access" {
  description = "Datos de acceso para la VM Windows de validacion manual por Bastion."
  value = {
    vm_name    = module.hub.jumpbox_name
    private_ip = module.hub.jumpbox_private_ip
    username   = var.jumpbox_admin_username
    bastion    = "Usar Azure Bastion en el Resource Group para abrir RDP privado"
  }
}

output "dns_forwarder_private_ip" {
  description = "IP privada de la VM DNS Forwarder."
  value       = module.hub.dns_forwarder_private_ip
}
