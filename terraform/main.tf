data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_slug}-${var.environment}-${var.unique_suffix}"

  jumpbox_admin_password = (
    var.jumpbox_admin_password == null || startswith(var.jumpbox_admin_password, "REEMPLAZAR_")
  ) ? var.mysql_administrator_password : var.jumpbox_admin_password

  default_tags = {
    Project       = "PrivateIntranet"
    Environment   = var.environment
    Owner         = "EquipoCloud"
    ManagedBy     = "Terraform"
    CostCenter    = "CloudClass"
    Workload      = "PrivateIntranet"
    Criticality   = "Medium"
    Region        = var.location
    Architecture  = "HubSpoke"
    ResourceScope = "SharedResourceGroup"
  }

  common_tags = merge(local.default_tags, var.tags)

  app_names = {
    webapp = "app-${local.name_prefix}-intranet"
    admin  = "app-${local.name_prefix}-admin"
    api    = "app-${local.name_prefix}-api"
  }

  storage_account_name = substr(lower(replace("st${var.project_slug}${var.environment}${var.unique_suffix}", "-", "")), 0, 24)

  app_gateway_backends = {
    intranet = {
      host_name    = var.internal_domains.intranet
      backend_fqdn = "${local.app_names.webapp}.azurewebsites.net"
      priority     = 100
    }
    admin = {
      host_name    = var.internal_domains.admin
      backend_fqdn = "${local.app_names.admin}.azurewebsites.net"
      priority     = 110
    }
    api = {
      host_name    = var.internal_domains.api
      backend_fqdn = "${local.app_names.api}.azurewebsites.net"
      priority     = 120
    }
  }

  internal_dns_records = {
    intranet = [var.hub.application_gateway_private_ip]
    admin    = [var.hub.application_gateway_private_ip]
    api      = [var.hub.application_gateway_private_ip]
    kpi      = [var.spoke3.dashboard_private_ip]
  }
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "hub" {
  source = "./modules/hub"

  resource_group_name  = azurerm_resource_group.main.name
  resource_group_id    = azurerm_resource_group.main.id
  location             = azurerm_resource_group.main.location
  name_prefix          = local.name_prefix
  tenant_id            = data.azurerm_client_config.current.tenant_id
  tags                 = local.common_tags
  config               = var.hub
  internal_dns_zone    = var.internal_domains.zone
  internal_dns_records = local.internal_dns_records
  internal_urls = {
    intranet  = "http://${var.internal_domains.intranet}"
    admin     = "http://${var.internal_domains.admin}"
    api       = "http://${var.internal_domains.api}/health"
    analytics = "http://${var.internal_domains.analytics}:8501"
  }
  jumpbox_admin_username = var.jumpbox_admin_username
  jumpbox_admin_password = local.jumpbox_admin_password
  private_dns_zone_names = {
    app_service = "privatelink.azurewebsites.net"
    mysql       = "privatelink.mysql.database.azure.com"
    blob        = "privatelink.blob.core.windows.net"
    key_vault   = "privatelink.vaultcore.azure.net"
  }
  application_gateway = {
    enabled            = var.hub.enable_application_gateway
    private_ip_address = var.hub.application_gateway_private_ip
    backends           = local.app_gateway_backends
  }
}

module "spoke2" {
  source = "./modules/spoke2"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  name_prefix                  = local.name_prefix
  tags                         = local.common_tags
  config                       = var.spoke2
  hub_vnet_id                  = module.hub.vnet_id
  hub_vnet_name                = module.hub.vnet_name
  use_remote_gateways          = var.hub.enable_vpn_gateway
  mysql_private_dns_zone_id    = module.hub.private_dns_zone_ids.mysql
  blob_private_dns_zone_id     = module.hub.private_dns_zone_ids.blob
  mysql_administrator_login    = var.mysql_administrator_login
  mysql_administrator_password = var.mysql_administrator_password
  storage_account_name         = local.storage_account_name

  spoke1_app_service_subnet_prefix = var.spoke1.app_service_integration_subnet_prefix
  spoke3_etl_subnet_prefix         = var.spoke3.etl_subnet_prefix
  spoke3_dashboard_subnet_prefix   = var.spoke3.dashboard_subnet_prefix
  hub_management_subnet_prefix     = var.hub.management_subnet_prefix

  depends_on = [module.hub]
}

module "spoke3" {
  source = "./modules/spoke3"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  name_prefix                  = local.name_prefix
  tags                         = local.common_tags
  config                       = var.spoke3
  hub_vnet_id                  = module.hub.vnet_id
  hub_vnet_name                = module.hub.vnet_name
  use_remote_gateways          = var.hub.enable_vpn_gateway
  mysql_private_dns_zone_id    = module.hub.private_dns_zone_ids.mysql
  mysql_administrator_login    = var.mysql_administrator_login
  mysql_administrator_password = var.mysql_administrator_password
  vm_admin_username            = var.vm_admin_username
  vm_admin_ssh_public_key      = var.vm_admin_ssh_public_key
  hub_bastion_subnet_prefix    = var.hub.bastion_subnet_prefix
  hub_management_subnet_prefix = var.hub.management_subnet_prefix
  source_paths = {
    dashboard  = abspath("${path.module}/../src/spoke3/dashboard")
    etl_runner = abspath("${path.module}/../src/spoke3/etl-runner")
  }
  upstream_databases = {
    app_host       = module.spoke2.mysql_app_fqdn
    app_database   = module.spoke2.mysql_app_database_name
    admin_host     = module.spoke2.mysql_admin_fqdn
    admin_database = module.spoke2.mysql_admin_database_name
  }

  depends_on = [module.hub, module.spoke2]
}

module "spoke1" {
  source = "./modules/spoke1"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  name_prefix                     = local.name_prefix
  tags                            = local.common_tags
  config                          = var.spoke1
  app_names                       = local.app_names
  hub_vnet_id                     = module.hub.vnet_id
  hub_vnet_name                   = module.hub.vnet_name
  use_remote_gateways             = var.hub.enable_vpn_gateway
  app_service_private_dns_zone_id = module.hub.private_dns_zone_ids.app_service
  internal_dns_zone_name          = var.internal_domains.zone
  hub_edge_subnet_prefix          = var.hub.edge_subnet_prefix
  hub_management_subnet_prefix    = var.hub.management_subnet_prefix
  source_paths = {
    webapp = abspath("${path.module}/../src/spoke1/webapp")
    admin  = abspath("${path.module}/../src/spoke1/admin")
    api    = abspath("${path.module}/../src/spoke1/api")
  }
  app_environment = {
    api_base_url         = "https://${local.app_names.api}.azurewebsites.net"
    mysql_app_host       = module.spoke2.mysql_app_fqdn
    mysql_app_database   = module.spoke2.mysql_app_database_name
    mysql_admin_host     = module.spoke2.mysql_admin_fqdn
    mysql_admin_database = module.spoke2.mysql_admin_database_name
    mysql_user           = var.mysql_administrator_login
    mysql_password       = var.mysql_administrator_password
    storage_account_url  = module.spoke2.storage_primary_blob_endpoint
    storage_account_key  = module.spoke2.storage_primary_access_key
    storage_container    = module.spoke2.storage_container_name
  }

  depends_on = [module.hub, module.spoke2]
}

# Peerings directos entre spokes para flujos privados que no pueden transitar por el hub.
resource "azurerm_virtual_network_peering" "spoke1_to_spoke2" {
  name                         = "peer-spoke1-app-to-spoke2-data"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = "vnet-${local.name_prefix}-spoke1-app"
  remote_virtual_network_id    = module.spoke2.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  use_remote_gateways          = false

  depends_on = [module.spoke1, module.spoke2]
}

resource "azurerm_virtual_network_peering" "spoke2_to_spoke1" {
  name                         = "peer-spoke2-data-to-spoke1-app"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = "vnet-${local.name_prefix}-spoke2-data"
  remote_virtual_network_id    = module.spoke1.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  use_remote_gateways          = false

  depends_on = [module.spoke1, module.spoke2]
}

resource "azurerm_virtual_network_peering" "spoke2_to_spoke3" {
  name                         = "peer-spoke2-data-to-spoke3-analytics"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = "vnet-${local.name_prefix}-spoke2-data"
  remote_virtual_network_id    = module.spoke3.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  use_remote_gateways          = false

  depends_on = [module.spoke2, module.spoke3]
}

resource "azurerm_virtual_network_peering" "spoke3_to_spoke2" {
  name                         = "peer-spoke3-analytics-to-spoke2-data"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = "vnet-${local.name_prefix}-spoke3-analytics"
  remote_virtual_network_id    = module.spoke2.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  use_remote_gateways          = false

  depends_on = [module.spoke2, module.spoke3]
}

# ── Script de diagnóstico renderizado con todos los endpoints ────
resource "local_file" "diagnostics_script" {
  filename        = "${path.module}/diagnostics.ps1"
  file_permission = "0600"
  content = templatefile("${path.module}/diagnostics.ps1.tftpl", {
    resource_group_name    = var.resource_group_name
    intranet_url           = "http://${var.internal_domains.intranet}"
    admin_url              = "http://${var.internal_domains.admin}"
    api_url                = "http://${var.internal_domains.api}/health"
    dns_intranet           = var.internal_domains.intranet
    dns_admin              = var.internal_domains.admin
    dns_api                = var.internal_domains.api
    dns_analytics          = var.internal_domains.analytics
    mysql_app_host         = module.spoke2.mysql_app_fqdn
    mysql_admin_host       = module.spoke2.mysql_admin_fqdn
    mysql_analytics_host   = module.spoke3.mysql_analytics_fqdn
    mysql_user             = var.mysql_administrator_login
    mysql_password         = var.mysql_administrator_password
    storage_account_name   = local.storage_account_name
    storage_blob_endpoint  = module.spoke2.storage_primary_blob_endpoint
    etl_private_ip         = var.spoke3.etl_private_ip
    dashboard_private_ip   = var.spoke3.dashboard_private_ip
    app_gateway_private_ip = var.hub.application_gateway_private_ip
    key_vault_name         = module.hub.key_vault_name
  })

  depends_on = [module.hub, module.spoke2, module.spoke3]
}
