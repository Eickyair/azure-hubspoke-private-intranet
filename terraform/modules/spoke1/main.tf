data "archive_file" "catalog_webapp" {
  type        = "zip"
  source_dir  = var.source_paths.catalog_webapp
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-webapp.zip"
}

data "archive_file" "admin_webapp" {
  type        = "zip"
  source_dir  = var.source_paths.admin_webapp
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-admin.zip"
}

data "archive_file" "catalog_api" {
  type        = "zip"
  source_dir  = var.source_paths.catalog_api
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-api.zip"
}

data "archive_file" "admin_api" {
  type        = "zip"
  source_dir  = var.source_paths.admin_api
  output_path = "${path.root}/.terraform-build/${var.name_prefix}-admin-api.zip"
}

locals {
  source_files = {
    webapp    = [for file in sort(fileset(var.source_paths.catalog_webapp, "**")) : file if file != "Dockerfile" && !endswith(file, ".pyc") && !strcontains(file, "__pycache__/")]
    admin     = [for file in sort(fileset(var.source_paths.admin_webapp, "**")) : file if file != "Dockerfile" && !endswith(file, ".pyc") && !strcontains(file, "__pycache__/")]
    api       = [for file in sort(fileset(var.source_paths.catalog_api, "**")) : file if file != "Dockerfile" && !endswith(file, ".pyc") && !strcontains(file, "__pycache__/")]
    admin_api = [for file in sort(fileset(var.source_paths.admin_api, "**")) : file if file != "Dockerfile" && !endswith(file, ".pyc") && !strcontains(file, "__pycache__/")]
  }

  package_hashes = {
    webapp    = sha256(join(":", [for file in local.source_files.webapp : "${file}:${filesha256("${var.source_paths.catalog_webapp}/${file}")}"]))
    admin     = sha256(join(":", [for file in local.source_files.admin : "${file}:${filesha256("${var.source_paths.admin_webapp}/${file}")}"]))
    api       = sha256(join(":", [for file in local.source_files.api : "${file}:${filesha256("${var.source_paths.catalog_api}/${file}")}"]))
    admin_api = sha256(join(":", [for file in local.source_files.admin_api : "${file}:${filesha256("${var.source_paths.admin_api}/${file}")}"]))
  }

  # Nombre del storage account de paquetes (max 24 chars, sin guiones)
  packages_sa_name = substr(lower(replace("stpkg${var.name_prefix}", "-", "")), 0, 24)

  prebuilt_package_names = {
    webapp    = "webapp-prebuilt-${local.package_hashes.webapp}.zip"
    admin     = "admin-prebuilt-${local.package_hashes.admin}.zip"
    api       = "api-prebuilt-${local.package_hashes.api}.zip"
    admin_api = "admin-api-prebuilt-${local.package_hashes.admin_api}.zip"
  }

  prebuilt_package_paths = {
    webapp    = "${path.root}/.terraform-build/prebuilt/${local.prebuilt_package_names.webapp}"
    admin     = "${path.root}/.terraform-build/prebuilt/${local.prebuilt_package_names.admin}"
    api       = "${path.root}/.terraform-build/prebuilt/${local.prebuilt_package_names.api}"
    admin_api = "${path.root}/.terraform-build/prebuilt/${local.prebuilt_package_names.admin_api}"
  }

  prebuilt_package_urls = {
    webapp    = "${azurerm_storage_account.packages.primary_blob_endpoint}${azurerm_storage_container.packages.name}/${local.prebuilt_package_names.webapp}${data.azurerm_storage_account_sas.packages.sas}"
    admin     = "${azurerm_storage_account.packages.primary_blob_endpoint}${azurerm_storage_container.packages.name}/${local.prebuilt_package_names.admin}${data.azurerm_storage_account_sas.packages.sas}"
    api       = "${azurerm_storage_account.packages.primary_blob_endpoint}${azurerm_storage_container.packages.name}/${local.prebuilt_package_names.api}${data.azurerm_storage_account_sas.packages.sas}"
    admin_api = "${azurerm_storage_account.packages.primary_blob_endpoint}${azurerm_storage_container.packages.name}/${local.prebuilt_package_names.admin_api}${data.azurerm_storage_account_sas.packages.sas}"
  }

  runtime_start_command = "bash -lc \"export PYTHONPATH=/home/site/wwwroot/packages:$PYTHONPATH; cd /home/site/wwwroot; exec python -m uvicorn main:app --host 0.0.0.0 --port 8000\""
}

# ── Storage account de despliegue (paquetes ZIP) ─────────────────────────────
# Acceso público habilitado para que el App Service pueda descargar los paquetes
# al arrancar (salida de Internet directa, vnet_route_all_enabled=false).
# El acceso está protegido por token SAS de sólo lectura.
resource "azurerm_storage_account" "packages" {
  name                            = local.packages_sa_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  shared_access_key_enabled       = true
  tags                            = var.tags
}

resource "azurerm_storage_container" "packages" {
  name                  = "app-packages"
  storage_account_name  = azurerm_storage_account.packages.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "webapp" {
  name                   = "webapp-${local.package_hashes.webapp}.zip"
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = data.archive_file.catalog_webapp.output_path
}

resource "azurerm_storage_blob" "admin" {
  name                   = "admin-${local.package_hashes.admin}.zip"
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = data.archive_file.admin_webapp.output_path
}

resource "azurerm_storage_blob" "api" {
  name                   = "api-${local.package_hashes.api}.zip"
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = data.archive_file.catalog_api.output_path
}

resource "azurerm_storage_blob" "admin_api" {
  name                   = "admin-api-${local.package_hashes.admin_api}.zip"
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = data.archive_file.admin_api.output_path
}

resource "azurerm_storage_blob" "webapp_prebuilt" {
  name                   = local.prebuilt_package_names.webapp
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = local.prebuilt_package_paths.webapp
}

resource "azurerm_storage_blob" "admin_prebuilt" {
  name                   = local.prebuilt_package_names.admin
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = local.prebuilt_package_paths.admin
}

resource "azurerm_storage_blob" "api_prebuilt" {
  name                   = local.prebuilt_package_names.api
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = local.prebuilt_package_paths.api
}

resource "azurerm_storage_blob" "admin_api_prebuilt" {
  name                   = local.prebuilt_package_names.admin_api
  storage_account_name   = azurerm_storage_account.packages.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = local.prebuilt_package_paths.admin_api
}

# SAS de sólo lectura con fecha de expiración fija (válido hasta 2030-12-31)
data "azurerm_storage_account_sas" "packages" {
  connection_string = azurerm_storage_account.packages.primary_connection_string
  https_only        = true
  start             = "2026-01-01T00:00:00Z"
  expiry            = "2030-12-31T23:59:59Z"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
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
  private_endpoint_network_policies = "Enabled"

  depends_on = [azurerm_subnet.app_service_integration]
}

resource "azurerm_network_security_group" "private_endpoint" {
  name                = "nsg-${var.name_prefix}-spoke1-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowAppGatewayHttps"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_edge_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowJumpboxHttps"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_management_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAppServiceIntegrationHttps"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.config.app_service_integration_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  subnet_id                 = azurerm_subnet.private_endpoint.id
  network_security_group_id = azurerm_network_security_group.private_endpoint.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke1-app"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.use_remote_gateways

  depends_on = [azurerm_subnet.private_endpoint]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke1-app-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.use_remote_gateways

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_service" {
  name                  = "pdz-${var.name_prefix}-web-spoke1-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.azurewebsites.net"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [azurerm_virtual_network_peering.spoke_to_hub]
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "pdz-${var.name_prefix}-internal-spoke1-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = var.internal_dns_zone_name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.app_service]
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "pdz-${var.name_prefix}-mysql-spoke1-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.mysql.database.azure.com"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.internal]
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "pdz-${var.name_prefix}-blob-spoke1-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.blob.core.windows.net"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
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
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = local.runtime_start_command
    ftps_state             = "Disabled"
    health_check_path      = "/live"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = false

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                        = "catalog-webapp"
    API_INTERNAL_URL                    = var.app_environment.catalog_api_internal_url
    API_EXTERNAL_URL                    = var.app_environment.catalog_api_external_url
    APP_PACKAGE_HASH                    = local.package_hashes.webapp
    WEBSITE_RUN_FROM_PACKAGE            = local.prebuilt_package_urls.webapp
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    ENABLE_ORYX_BUILD                   = "false"
    WEBSITES_CONTAINER_START_TIME_LIMIT = "1800"
    WEBSITES_PORT                       = "8000"
  }

  depends_on = [azurerm_storage_blob.webapp_prebuilt, azurerm_private_dns_zone_virtual_network_link.blob]
}

resource "azurerm_linux_web_app" "admin" {
  name                          = var.app_names.admin
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = local.runtime_start_command
    ftps_state             = "Disabled"
    health_check_path      = "/live"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = false

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                        = "admin-webapp"
    API_INTERNAL_URL                    = var.app_environment.admin_api_internal_url
    API_EXTERNAL_URL                    = var.app_environment.admin_api_external_url
    CATALOG_API_EXTERNAL_URL            = var.app_environment.catalog_api_external_url
    APP_PACKAGE_HASH                    = local.package_hashes.admin
    WEBSITE_RUN_FROM_PACKAGE            = local.prebuilt_package_urls.admin
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    ENABLE_ORYX_BUILD                   = "false"
    WEBSITES_CONTAINER_START_TIME_LIMIT = "1800"
    WEBSITES_PORT                       = "8000"
  }

  depends_on = [azurerm_storage_blob.admin_prebuilt, azurerm_linux_web_app.webapp]
}

resource "azurerm_linux_web_app" "api" {
  name                          = var.app_names.api
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = local.runtime_start_command
    ftps_state             = "Disabled"
    health_check_path      = "/live"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = false

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                        = "catalog-api"
    MYSQL_APP_HOST                      = var.app_environment.mysql_app_host
    MYSQL_APP_DATABASE                  = var.app_environment.mysql_app_database
    MYSQL_APP_USER                      = var.app_environment.mysql_user
    MYSQL_APP_PASSWORD                  = var.app_environment.mysql_password
    MYSQL_ADMIN_HOST                    = var.app_environment.mysql_admin_host
    MYSQL_ADMIN_DATABASE                = var.app_environment.mysql_admin_database
    MYSQL_ADMIN_USER                    = var.app_environment.mysql_user
    MYSQL_ADMIN_PASSWORD                = var.app_environment.mysql_password
    STORAGE_ACCOUNT_URL                 = var.app_environment.storage_account_url
    STORAGE_ACCOUNT_KEY                 = var.app_environment.storage_account_key
    STORAGE_CONTAINER_NAME              = var.app_environment.storage_container
    APP_PACKAGE_HASH                    = local.package_hashes.api
    WEBSITE_RUN_FROM_PACKAGE            = local.prebuilt_package_urls.api
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    ENABLE_ORYX_BUILD                   = "false"
    WEBSITES_CONTAINER_START_TIME_LIMIT = "1800"
    WEBSITES_PORT                       = "8000"
  }

  depends_on = [azurerm_storage_blob.api_prebuilt, azurerm_linux_web_app.admin]
}

resource "azurerm_linux_web_app" "admin_api" {
  name                          = var.app_names.admin_api
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.main.id
  https_only                    = true
  public_network_access_enabled = var.config.public_network_access_enabled
  virtual_network_subnet_id     = azurerm_subnet.app_service_integration.id
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    app_command_line       = local.runtime_start_command
    ftps_state             = "Disabled"
    health_check_path      = "/live"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = false

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SERVICE_NAME                        = "admin-api"
    MYSQL_APP_HOST                      = var.app_environment.mysql_admin_host
    MYSQL_APP_DATABASE                  = var.app_environment.mysql_admin_database
    MYSQL_APP_USER                      = var.app_environment.mysql_user
    MYSQL_APP_PASSWORD                  = var.app_environment.mysql_password
    STORAGE_ACCOUNT_URL                 = var.app_environment.storage_account_url
    STORAGE_ACCOUNT_KEY                 = var.app_environment.storage_account_key
    STORAGE_CONTAINER_NAME              = var.app_environment.storage_container
    APP_PACKAGE_HASH                    = local.package_hashes.admin_api
    WEBSITE_RUN_FROM_PACKAGE            = local.prebuilt_package_urls.admin_api
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "false"
    ENABLE_ORYX_BUILD                   = "false"
    WEBSITES_CONTAINER_START_TIME_LIMIT = "1800"
    WEBSITES_PORT                       = "8000"
  }

  depends_on = [azurerm_storage_blob.admin_api_prebuilt, azurerm_linux_web_app.api]
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

  depends_on = [azurerm_linux_web_app.admin_api]
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

  depends_on = [azurerm_private_endpoint.webapp]
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

  depends_on = [azurerm_private_endpoint.admin]
}

resource "azurerm_private_endpoint" "admin_api" {
  name                = "pe-${var.name_prefix}-admin-api-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-admin-api-web"
    private_connection_resource_id = azurerm_linux_web_app.admin_api.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.app_service_private_dns_zone_id]
  }

  depends_on = [azurerm_private_endpoint.api]
}
