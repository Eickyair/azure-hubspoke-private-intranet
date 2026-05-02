resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-spoke3-analytics"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "etl" {
  name                 = "snet-${var.name_prefix}-spoke3-etl"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.config.etl_subnet_prefix]
}

resource "azurerm_subnet" "dashboard" {
  name                 = "snet-${var.name_prefix}-spoke3-dashboard"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.config.dashboard_subnet_prefix]
}

resource "azurerm_subnet" "mysql" {
  name                 = "snet-${var.name_prefix}-spoke3-mysql"
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

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke3-analytics"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke3-analytics-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "pdz-${var.name_prefix}-mysql-spoke3-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.mysql.database.azure.com"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_network_security_group" "etl" {
  name                = "nsg-${var.name_prefix}-spoke3-etl"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVNetFastApi"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVNetSshForBastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "dashboard" {
  name                = "nsg-${var.name_prefix}-spoke3-dashboard"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVNetStreamlit"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8501"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVNetSshForBastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "etl" {
  subnet_id                 = azurerm_subnet.etl.id
  network_security_group_id = azurerm_network_security_group.etl.id
}

resource "azurerm_subnet_network_security_group_association" "dashboard" {
  subnet_id                 = azurerm_subnet.dashboard.id
  network_security_group_id = azurerm_network_security_group.dashboard.id
}

resource "azurerm_mysql_flexible_server" "analytics" {
  name                   = "mysql-${var.name_prefix}-analytics"
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

resource "azurerm_mysql_flexible_database" "analytics" {
  name                = var.config.analytics_database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.analytics.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

locals {
  etl_env = {
    SERVICE_NAME             = "etl-runner-01"
    MYSQL_APP_HOST           = var.upstream_databases.app_host
    MYSQL_APP_DATABASE       = var.upstream_databases.app_database
    MYSQL_APP_USER           = var.mysql_administrator_login
    MYSQL_APP_PASSWORD       = var.mysql_administrator_password
    MYSQL_ADMIN_HOST         = var.upstream_databases.admin_host
    MYSQL_ADMIN_DATABASE     = var.upstream_databases.admin_database
    MYSQL_ADMIN_USER         = var.mysql_administrator_login
    MYSQL_ADMIN_PASSWORD     = var.mysql_administrator_password
    MYSQL_ANALYTICS_HOST     = azurerm_mysql_flexible_server.analytics.fqdn
    MYSQL_ANALYTICS_DATABASE = azurerm_mysql_flexible_database.analytics.name
    MYSQL_ANALYTICS_USER     = var.mysql_administrator_login
    MYSQL_ANALYTICS_PASSWORD = var.mysql_administrator_password
  }

  dashboard_env = {
    SERVICE_NAME             = "dashboard-kpi-01"
    ETL_HEALTH_URL           = "http://${var.config.etl_private_ip}:8000/health"
    MYSQL_APP_HOST           = var.upstream_databases.app_host
    MYSQL_APP_DATABASE       = var.upstream_databases.app_database
    MYSQL_APP_USER           = var.mysql_administrator_login
    MYSQL_APP_PASSWORD       = var.mysql_administrator_password
    MYSQL_ADMIN_HOST         = var.upstream_databases.admin_host
    MYSQL_ADMIN_DATABASE     = var.upstream_databases.admin_database
    MYSQL_ADMIN_USER         = var.mysql_administrator_login
    MYSQL_ADMIN_PASSWORD     = var.mysql_administrator_password
    MYSQL_ANALYTICS_HOST     = azurerm_mysql_flexible_server.analytics.fqdn
    MYSQL_ANALYTICS_DATABASE = azurerm_mysql_flexible_database.analytics.name
    MYSQL_ANALYTICS_USER     = var.mysql_administrator_login
    MYSQL_ANALYTICS_PASSWORD = var.mysql_administrator_password
  }
}

resource "azurerm_network_interface" "etl" {
  name                = "nic-${var.name_prefix}-etl"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.etl.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.config.etl_private_ip
  }
}

resource "azurerm_network_interface" "dashboard" {
  name                = "nic-${var.name_prefix}-dashboard"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.dashboard.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.config.dashboard_private_ip
  }
}

resource "azurerm_linux_virtual_machine" "etl" {
  name                            = "vm-${var.name_prefix}-etl-01"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.config.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.etl.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init-fastapi.yaml.tftpl", {
    service_name     = "etl-runner"
    main_py_b64      = filebase64("${var.source_paths.etl_runner}/main.py")
    requirements_b64 = filebase64("${var.source_paths.etl_runner}/requirements.txt")
    env_b64          = base64encode(join("\n", [for key, value in local.etl_env : "${key}=${value}"]))
  }))
  tags = var.tags

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "dashboard" {
  name                            = "vm-${var.name_prefix}-dashboard-01"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.config.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.dashboard.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init-streamlit.yaml.tftpl", {
    service_name     = "dashboard-kpi"
    main_py_b64      = filebase64("${var.source_paths.dashboard}/main.py")
    requirements_b64 = filebase64("${var.source_paths.dashboard}/requirements.txt")
    env_b64          = base64encode(join("\n", [for key, value in local.dashboard_env : "${key}=${value}"]))
  }))
  tags = var.tags

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
