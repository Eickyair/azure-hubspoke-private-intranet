resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-spoke2-data"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "mysql" {
  name                 = "snet-${var.name_prefix}-spoke2-mysql"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.config.mysql_subnet_prefix]

  delegation {
    name = "mysql-flexible-server"

    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoint" {
  name                              = "snet-${var.name_prefix}-spoke2-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [var.config.private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke2-data"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke2-data-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "pdz-${var.name_prefix}-mysql-spoke2-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.mysql.database.azure.com"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "pdz-${var.name_prefix}-blob-spoke2-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.blob.core.windows.net"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_mysql_flexible_server" "app" {
  name                   = "mysql-${var.name_prefix}-app"
  location               = var.location
  resource_group_name    = var.resource_group_name
  administrator_login    = var.mysql_administrator_login
  administrator_password = var.mysql_administrator_password
  backup_retention_days  = var.config.mysql_backup_retention_days
  delegated_subnet_id    = azurerm_subnet.mysql.id
  private_dns_zone_id    = var.mysql_private_dns_zone_id
  sku_name               = var.config.mysql_sku_name
  version                = var.config.mysql_version
  tags                   = var.tags

  storage {
    size_gb = var.config.mysql_storage_gb
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_server" "admin" {
  name                   = "mysql-${var.name_prefix}-admin"
  location               = var.location
  resource_group_name    = var.resource_group_name
  administrator_login    = var.mysql_administrator_login
  administrator_password = var.mysql_administrator_password
  backup_retention_days  = var.config.mysql_backup_retention_days
  delegated_subnet_id    = azurerm_subnet.mysql.id
  private_dns_zone_id    = var.mysql_private_dns_zone_id
  sku_name               = var.config.mysql_sku_name
  version                = var.config.mysql_version
  tags                   = var.tags

  storage {
    size_gb = var.config.mysql_storage_gb
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_database" "app" {
  name                = var.config.app_database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.app.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_database" "admin" {
  name                = var.config.admin_database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.admin.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_storage_account" "documents" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  shared_access_key_enabled       = true
  tags                            = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "documents" {
  name                  = var.config.storage_container_name
  storage_account_name  = azurerm_storage_account.documents.name
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name_prefix}-blob-docs"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-blob-docs"
    private_connection_resource_id = azurerm_storage_account.documents.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.blob_private_dns_zone_id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.blob]
}
