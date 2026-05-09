variable "resource_group_name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "config" {
  type = object({
    address_space                         = list(string)
    gateway_subnet_prefix                 = string
    bastion_subnet_prefix                 = string
    edge_subnet_prefix                    = string
    shared_private_endpoint_subnet_prefix = string
    management_subnet_prefix              = string
    p2s_address_space                     = list(string)
    enable_vpn_gateway                    = bool
    vpn_root_certificate_name             = string
    vpn_root_certificate_data             = string
    enable_application_gateway            = bool
    application_gateway_private_ip        = string
    enable_test_vm                        = bool
    grant_test_vm_rbac                    = bool
    jumpbox_private_ip                    = string
    jumpbox_vm_size                       = string
  })
}

variable "private_dns_zone_names" {
  type = object({
    app_service = string
    mysql       = string
    blob        = string
    key_vault   = string
  })
}

variable "internal_dns_zone" {
  type = string
}

variable "internal_dns_records" {
  type = map(list(string))
}

variable "application_gateway" {
  type = object({
    enabled            = bool
    private_ip_address = string
    backends = map(object({
      host_name    = string
      backend_fqdn = string
      priority     = number
    }))
  })
}

variable "internal_urls" {
  type = object({
    intranet  = string
    admin     = string
    api       = string
    analytics = string
  })
}

variable "jumpbox_admin_username" {
  type = string
}

variable "jumpbox_admin_password" {
  type      = string
  sensitive = true
}
