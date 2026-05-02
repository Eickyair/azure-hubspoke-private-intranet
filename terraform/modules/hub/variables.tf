variable "resource_group_name" {
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
    p2s_address_space                     = list(string)
    enable_vpn_gateway                    = bool
    vpn_root_certificate_name             = string
    vpn_root_certificate_data             = string
    enable_application_gateway            = bool
    application_gateway_private_ip        = string
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
