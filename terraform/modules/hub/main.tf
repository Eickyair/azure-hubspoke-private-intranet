locals {
  private_dns_zones = {
    app_service = var.private_dns_zone_names.app_service
    mysql       = var.private_dns_zone_names.mysql
    blob        = var.private_dns_zone_names.blob
    key_vault   = var.private_dns_zone_names.key_vault
  }

  application_gateway_backends = var.application_gateway.enabled ? var.application_gateway.backends : {}

  key_vault_name = substr(lower("kv${replace(var.name_prefix, "-", "")}${random_string.kv_suffix.result}"), 0, 24)

  jumpbox_bootstrap_script_b64 = base64encode(templatefile("${path.module}/jumpbox-init.ps1.tftpl", {
    intranet_url        = var.internal_urls.intranet
    admin_url           = var.internal_urls.admin
    api_url             = var.internal_urls.api
    analytics_url       = var.internal_urls.analytics
    resource_group_name = var.resource_group_name
    root_ca_cert_b64    = filebase64("${path.module}/../../.vpn-certs/ca.crt")
  }))
}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.config.address_space
  tags                = var.tags
  dns_servers         = var.config.enable_vpn_gateway ? ["10.10.4.50"] : null
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

  depends_on = [azurerm_subnet.gateway]
}

resource "azurerm_subnet" "edge" {
  name                 = "snet-${var.name_prefix}-hub-edge"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.config.edge_subnet_prefix]

  depends_on = [azurerm_subnet.bastion]
}

resource "azurerm_subnet" "shared_private_endpoint" {
  name                              = "snet-${var.name_prefix}-hub-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [var.config.shared_private_endpoint_subnet_prefix]
  private_endpoint_network_policies = "Disabled"

  depends_on = [azurerm_subnet.edge]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-${var.name_prefix}-hub-mgmt"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.config.management_subnet_prefix]

  depends_on = [azurerm_subnet.shared_private_endpoint]
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
  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  public_network_access_enabled = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  tags                          = var.tags
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "appgw" {
  name                = "id-${var.name_prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "appgw_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

resource "azurerm_role_assignment" "deployer_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "appgw_cert" {
  name         = "cert-northwind-lab"
  value        = filebase64("${path.module}/../../.vpn-certs/cert-northwind-lab.pfx")
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application/x-pkcs12"

  depends_on = [
    azurerm_role_assignment.deployer_kv_secrets_officer
  ]
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${var.name_prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.shared_private_endpoint.id
  tags                = var.tags

  depends_on = [azurerm_subnet.management]

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

  depends_on = [azurerm_subnet.management]

  ip_configuration {
    name                 = "default"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "management" {
  count               = var.config.enable_test_vm ? 1 : 0
  name                = "nsg-${var.name_prefix}-hub-mgmt"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowBastionRdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.config.bastion_subnet_prefix
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "management" {
  count                     = var.config.enable_test_vm ? 1 : 0
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management[0].id
}

resource "azurerm_network_interface" "jumpbox" {
  count               = var.config.enable_test_vm ? 1 : 0
  name                = "nic-${var.name_prefix}-jumpbox"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.config.jumpbox_private_ip
  }
}

resource "azurerm_windows_virtual_machine" "jumpbox" {
  count                 = var.config.enable_test_vm ? 1 : 0
  name                  = "vm-${var.name_prefix}-jumpbox-01"
  computer_name         = "jumpbox01"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.config.jumpbox_vm_size
  admin_username        = var.jumpbox_admin_username
  admin_password        = var.jumpbox_admin_password
  network_interface_ids = [azurerm_network_interface.jumpbox[0].id]
  provision_vm_agent    = true
  tags                  = var.tags

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "jumpbox_init" {
  count                = var.config.enable_test_vm ? 1 : 0
  name                 = "vmext-${var.name_prefix}-jumpbox-init"
  virtual_machine_id   = azurerm_windows_virtual_machine.jumpbox[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"[IO.File]::WriteAllText('C:\\\\Windows\\\\Temp\\\\jumpbox-init.ps1',[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${local.jumpbox_bootstrap_script_b64}'))); & 'C:\\\\Windows\\\\Temp\\\\jumpbox-init.ps1'\""
  })
}

resource "azurerm_role_assignment" "jumpbox_contributor" {
  count                = var.config.enable_test_vm && var.config.grant_test_vm_rbac ? 1 : 0
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_virtual_machine.jumpbox[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "jumpbox_key_vault_admin" {
  count                = var.config.enable_test_vm && var.config.grant_test_vm_rbac ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_windows_virtual_machine.jumpbox[0].identity[0].principal_id
}

resource "azurerm_public_ip" "vpn" {
  count               = var.config.enable_vpn_gateway ? 1 : 0
  name                = "pip-${var.name_prefix}-vpn"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
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
  sku                 = "VpnGw1AZ"
  generation          = "Generation1"
  tags                = var.tags

  depends_on = [azurerm_subnet.management]

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

resource "azurerm_web_application_firewall_policy" "main" {
  count               = var.application_gateway.enabled ? 1 : 0
  name                = "waf-${var.name_prefix}-agw"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_public_ip" "application_gateway" {
  count               = var.application_gateway.enabled ? 1 : 0
  name                = "pip-${var.name_prefix}-agw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "main" {
  count               = var.application_gateway.enabled ? 1 : 0
  name                = "agw-${var.name_prefix}-private"
  location            = var.location
  resource_group_name = var.resource_group_name
  firewall_policy_id  = azurerm_web_application_firewall_policy.main[0].id
  tags                = var.tags

  depends_on = [
    azurerm_subnet.management,
    azurerm_role_assignment.appgw_kv_secrets_user
  ]

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
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

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.application_gateway[0].id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  ssl_certificate {
    name                = "cert-northwind-lab"
    key_vault_secret_id = azurerm_key_vault_secret.appgw_cert.versionless_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  dynamic "backend_address_pool" {
    for_each = local.application_gateway_backends
    content {
      name         = "be-${backend_address_pool.key}"
      fqdns        = length(backend_address_pool.value.backend_fqdns) > 0 ? backend_address_pool.value.backend_fqdns : null
      ip_addresses = length(backend_address_pool.value.backend_ip_addresses) > 0 ? backend_address_pool.value.backend_ip_addresses : null
    }
  }

  dynamic "probe" {
    for_each = local.application_gateway_backends
    content {
      name                                      = "probe-${probe.key}"
      protocol                                  = probe.value.backend_protocol
      path                                      = probe.value.probe_path
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      host                                      = probe.value.pick_host_name_from_backend_http_settings ? null : probe.value.host_name
      pick_host_name_from_backend_http_settings = probe.value.pick_host_name_from_backend_http_settings
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.application_gateway_backends
    content {
      name                                = "bhs-${backend_http_settings.key}"
      cookie_based_affinity               = "Disabled"
      port                                = backend_http_settings.value.backend_port
      protocol                            = backend_http_settings.value.backend_protocol
      request_timeout                     = 30
      host_name                           = backend_http_settings.value.pick_host_name_from_backend_address ? null : backend_http_settings.value.host_name
      pick_host_name_from_backend_address = backend_http_settings.value.pick_host_name_from_backend_address
      probe_name                          = "probe-${backend_http_settings.key}"
    }
  }

  # Listeners HTTP (Puerto 80) para redireccionamiento
  dynamic "http_listener" {
    for_each = local.application_gateway_backends
    content {
      name                           = "lst-http-${http_listener.key}"
      frontend_ip_configuration_name = "private-frontend"
      frontend_port_name             = "port-80"
      protocol                       = "Http"
      host_name                      = http_listener.value.host_name
    }
  }

  # Listeners HTTPS (Puerto 443) con SSL
  dynamic "http_listener" {
    for_each = local.application_gateway_backends
    content {
      name                           = "lst-https-${http_listener.key}"
      frontend_ip_configuration_name = "private-frontend"
      frontend_port_name             = "port-443"
      protocol                       = "Https"
      host_name                      = http_listener.value.host_name
      ssl_certificate_name           = "cert-northwind-lab"
    }
  }

  dynamic "redirect_configuration" {
    for_each = local.application_gateway_backends
    content {
      name                 = "redir-${redirect_configuration.key}"
      redirect_type        = "Permanent"
      target_listener_name = "lst-https-${redirect_configuration.key}"
      include_path         = true
      include_query_string = true
    }
  }

  # Reglas HTTP: Redireccionan a HTTPS
  dynamic "request_routing_rule" {
    for_each = local.application_gateway_backends
    content {
      name                        = "rule-http-${request_routing_rule.key}"
      priority                    = request_routing_rule.value.priority
      rule_type                   = "Basic"
      http_listener_name          = "lst-http-${request_routing_rule.key}"
      redirect_configuration_name = "redir-${request_routing_rule.key}"
    }
  }

  # Reglas HTTPS: Enrutan al Backend Pool
  dynamic "request_routing_rule" {
    for_each = local.application_gateway_backends
    content {
      name                       = "rule-https-${request_routing_rule.key}"
      priority                   = request_routing_rule.value.priority + 1000
      rule_type                  = "Basic"
      http_listener_name         = "lst-https-${request_routing_rule.key}"
      backend_address_pool_name  = "be-${request_routing_rule.key}"
      backend_http_settings_name = "bhs-${request_routing_rule.key}"
    }
  }
}

# ── DNS Forwarder Virtual Machine ───────────────────────────────────

resource "azurerm_network_interface" "dns" {
  count               = var.config.enable_vpn_gateway ? 1 : 0
  name                = "nic-${var.name_prefix}-dns-forwarder"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.4.50"
  }
}

resource "azurerm_network_security_group" "dns" {
  count               = var.config.enable_vpn_gateway ? 1 : 0
  name                = "nsg-${var.name_prefix}-hub-dns"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVpnDnsUdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefixes    = concat(var.config.address_space, var.config.p2s_address_space)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVpnDnsTcp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefixes    = concat(var.config.address_space, var.config.p2s_address_space)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowMgmtSsh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = [var.config.management_subnet_prefix, var.config.bastion_subnet_prefix]
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

resource "azurerm_network_interface_security_group_association" "dns" {
  count                     = var.config.enable_vpn_gateway ? 1 : 0
  network_interface_id      = azurerm_network_interface.dns[0].id
  network_security_group_id = azurerm_network_security_group.dns[0].id
}

resource "azurerm_linux_virtual_machine" "dns" {
  count                           = var.config.enable_vpn_gateway ? 1 : 0
  name                            = "vm-${var.name_prefix}-dns-01"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = "Standard_B2ls_v2"
  admin_username                  = "dnsadmin"
  admin_password                  = "DnsServerP@ssw0rd!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.dns[0].id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
              #!/bin/bash
              # 1. Usar temporalmente el DNS de Azure para la descarga e instalación de paquetes
              echo "nameserver 168.63.129.16" > /etc/resolv.conf

              # 2. Instalar dnsmasq
              apt-get update
              apt-get install -y dnsmasq

              # 3. Deshabilitar systemd-resolved para liberar el puerto 53
              systemctl stop systemd-resolved
              systemctl disable systemd-resolved

              # 4. Configurar dnsmasq como reenviador al DNS interno de Azure (168.63.129.16)
              cat <<EOT > /etc/dnsmasq.conf
              no-resolv
              server=168.63.129.16
              interface=*
              bind-interfaces
              cache-size=1000
              log-queries
              EOT

              # 5. Establecer resolv.conf local definitivo para el sistema local
              echo "nameserver 127.0.0.1" > /etc/resolv.conf

              # 6. Habilitar y reiniciar dnsmasq
              systemctl restart dnsmasq
              systemctl enable dnsmasq
              EOF
  )
}
