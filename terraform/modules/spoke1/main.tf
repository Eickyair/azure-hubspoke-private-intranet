data "archive_file" "webapp" {
  type        = "zip"
  source_dir  = var.source_paths.webapp
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-webapp.zip"
}

data "archive_file" "admin" {
  type        = "zip"
  source_dir  = var.source_paths.admin
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-admin.zip"
}

data "archive_file" "api" {
  type        = "zip"
  source_dir  = var.source_paths.api
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-api.zip"
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-spoke1-app"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "app_service_integration" {
  name                 = "snet-${var.name_prefix}-spoke1-appsvc"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.config.app_service_integration_subnet_prefix]

  delegation {
    name = "app-service-plan"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoint" {
  name                              = "snet-${var.name_prefix}-spoke1-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [var.config.private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke1-app"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke1-app-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_service" {
  name                  = "pdz-${var.name_prefix}-web-spoke1-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.azurewebsites.net"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}-spoke1"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.config.app_service_plan_sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "webapp" {
  name                          = var.app_names.webapp
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  zip_deploy_file               = var.config.deploy_source_zip ? data.archive_file.webapp.output_path : null
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = "python -m uvicorn main:app --host 0.0.0.0 --port 8000"
    ftps_state             = "Disabled"
    health_check_path      = "/health"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                   = "web-intranet"
    API_BASE_URL                   = var.app_environment.api_base_url
    API_HEALTH_PATH                = "/health"
    REQUEST_TIMEOUT_SECONDS        = "4"
    VERIFY_TLS                     = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENABLE_ORYX_BUILD              = "true"
    WEBSITES_PORT                  = "8000"
  }
}

resource "azurerm_linux_web_app" "admin" {
  name                          = var.app_names.admin
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  zip_deploy_file               = var.config.deploy_source_zip ? data.archive_file.admin.output_path : null
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = "python -m uvicorn main:app --host 0.0.0.0 --port 8000"
    ftps_state             = "Disabled"
    health_check_path      = "/health"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                   = "web-admin"
    API_BASE_URL                   = var.app_environment.api_base_url
    API_HEALTH_PATH                = "/health"
    MYSQL_ADMIN_HOST               = var.app_environment.mysql_admin_host
    MYSQL_ADMIN_DATABASE           = var.app_environment.mysql_admin_database
    MYSQL_ADMIN_USER               = var.app_environment.mysql_user
    MYSQL_ADMIN_PASSWORD           = var.app_environment.mysql_password
    REQUEST_TIMEOUT_SECONDS        = "4"
    VERIFY_TLS                     = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENABLE_ORYX_BUILD              = "true"
    WEBSITES_PORT                  = "8000"
  }
}

resource "azurerm_linux_web_app" "api" {
  name                          = var.app_names.api
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  zip_deploy_file               = var.config.deploy_source_zip ? data.archive_file.api.output_path : null
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = "python -m uvicorn main:app --host 0.0.0.0 --port 8000"
    ftps_state             = "Disabled"
    health_check_path      = "/health"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                   = "api-private"
    MYSQL_APP_HOST                 = var.app_environment.mysql_app_host
    MYSQL_APP_DATABASE             = var.app_environment.mysql_app_database
    MYSQL_APP_USER                 = var.app_environment.mysql_user
    MYSQL_APP_PASSWORD             = var.app_environment.mysql_password
    MYSQL_ADMIN_HOST               = var.app_environment.mysql_admin_host
    MYSQL_ADMIN_DATABASE           = var.app_environment.mysql_admin_database
    MYSQL_ADMIN_USER               = var.app_environment.mysql_user
    MYSQL_ADMIN_PASSWORD           = var.app_environment.mysql_password
    STORAGE_ACCOUNT_URL            = var.app_environment.storage_account_url
    STORAGE_ACCOUNT_KEY            = var.app_environment.storage_account_key
    STORAGE_CONTAINER_NAME         = var.app_environment.storage_container
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENABLE_ORYX_BUILD              = "true"
    WEBSITES_PORT                  = "8000"
  }
}

resource "azurerm_private_endpoint" "webapp" {
  name                = "pe-${var.name_prefix}-intranet-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-intranet-web"
    private_connection_resource_id = azurerm_linux_web_app.webapp.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.app_service_private_dns_zone_id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.app_service]
}

resource "azurerm_private_endpoint" "admin" {
  name                = "pe-${var.name_prefix}-admin-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-admin-web"
    private_connection_resource_id = azurerm_linux_web_app.admin.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.app_service_private_dns_zone_id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.app_service]
}

resource "azurerm_private_endpoint" "api" {
  name                = "pe-${var.name_prefix}-api-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-api-web"
    private_connection_resource_id = azurerm_linux_web_app.api.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.app_service_private_dns_zone_id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.app_service]
}
