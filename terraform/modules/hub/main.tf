locals {
  private_dns_zones = {
    app_service = var.private_dns_zone_names.app_service
    mysql       = var.private_dns_zone_names.mysql
    blob        = var.private_dns_zone_names.blob
    key_vault   = var.private_dns_zone_names.key_vault
  }

  application_gateway_backends = var.application_gateway.enabled ? var.application_gateway.backends : {}
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.config.gateway_subnet_prefix]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.config.bastion_subnet_prefix]
}

resource "azurerm_subnet" "edge" {
  name                 = "snet-${var.name_prefix}-hub-edge"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.config.edge_subnet_prefix]
}

resource "azurerm_subnet" "shared_private_endpoint" {
  name                              = "snet-${var.name_prefix}-hub-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [var.config.shared_private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_dns_zone" "shared" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.shared
  name                  = "pdz-${var.name_prefix}-${each.key}-hub-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "internal" {
  name                = var.internal_dns_zone
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal_hub" {
  name                  = "pdz-${var.name_prefix}-internal-hub-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "internal" {
  for_each            = var.internal_dns_records
  name                = each.key
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = each.value
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.name_prefix}-shared"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_key_vault" "main" {
  name                          = substr(replace("kv-${var.name_prefix}", "-", ""), 0, 24)
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${var.name_prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.shared_private_endpoint.id
  tags                = var.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }

  private_service_connection {
    name                           = "psc-${var.name_prefix}-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.shared["key_vault"].id]
  }
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.name_prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "default"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_public_ip" "vpn" {
  count               = var.config.enable_vpn_gateway ? 1 : 0
  name                = "pip-${var.name_prefix}-vpn"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.config.enable_vpn_gateway ? 1 : 0
  name                = "vpngw-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1"
  generation          = "Generation1"
  tags                = var.tags

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vpn[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  dynamic "vpn_client_configuration" {
    for_each = var.config.vpn_root_certificate_data != "" ? [1] : []
    content {
      address_space        = var.config.p2s_address_space
      vpn_auth_types       = ["Certificate"]
      vpn_client_protocols = ["OpenVPN"]

      root_certificate {
        name             = var.config.vpn_root_certificate_name
        public_cert_data = var.config.vpn_root_certificate_data
      }
    }
  }
}

resource "azurerm_application_gateway" "main" {
  count               = var.application_gateway.enabled ? 1 : 0
  name                = "agw-${var.name_prefix}-private"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gwip"
    subnet_id = azurerm_subnet.edge.id
  }

  frontend_ip_configuration {
    name                          = "private-frontend"
    subnet_id                     = azurerm_subnet.edge.id
    private_ip_address            = var.application_gateway.private_ip_address
    private_ip_address_allocation = "Static"
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  dynamic "backend_address_pool" {
    for_each = local.application_gateway_backends
    content {
      name  = "be-${backend_address_pool.key}"
      fqdns = [backend_address_pool.value.backend_fqdn]
    }
  }

  dynamic "probe" {
    for_each = local.application_gateway_backends
    content {
      name                                      = "probe-${probe.key}"
      protocol                                  = "Https"
      path                                      = "/health"
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = true
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.application_gateway_backends
    content {
      name                                = "bhs-${backend_http_settings.key}"
      cookie_based_affinity               = "Disabled"
      port                                = 443
      protocol                            = "Https"
      request_timeout                     = 30
      pick_host_name_from_backend_address = true
      probe_name                          = "probe-${backend_http_settings.key}"
    }
  }

  dynamic "http_listener" {
    for_each = local.application_gateway_backends
    content {
      name                           = "lst-${http_listener.key}"
      frontend_ip_configuration_name = "private-frontend"
      frontend_port_name             = "port-80"
      protocol                       = "Http"
      host_name                      = http_listener.value.host_name
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.application_gateway_backends
    content {
      name                       = "rule-${request_routing_rule.key}"
      priority                   = request_routing_rule.value.priority
      rule_type                  = "Basic"
      http_listener_name         = "lst-${request_routing_rule.key}"
      backend_address_pool_name  = "be-${request_routing_rule.key}"
      backend_http_settings_name = "bhs-${request_routing_rule.key}"
    }
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}
