variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "config" {
  type = object({
    address_space                         = list(string)
    app_service_integration_subnet_prefix = string
    private_endpoint_subnet_prefix        = string
    app_service_plan_sku_name             = string
    public_network_access_enabled         = bool
  })
}

variable "app_names" {
  type = object({
    webapp    = string
    admin     = string
    api       = string
    admin_api = string
  })
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "use_remote_gateways" {
  type = bool
}

variable "app_service_private_dns_zone_id" {
  type = string
}

variable "internal_dns_zone_name" {
  type = string
}

variable "hub_edge_subnet_prefix" {
  type        = string
  description = "CIDR del hub edge subnet (App Gateway) para permitir acceso HTTPS a los Private Endpoints."
}

variable "hub_management_subnet_prefix" {
  type        = string
  description = "CIDR del hub management subnet (Jumpbox) para permitir acceso HTTPS a los Private Endpoints."
}

variable "source_paths" {
  type = object({
    catalog_webapp = string
    catalog_api    = string
    admin_webapp   = string
    admin_api      = string
  })
}

variable "app_environment" {
  type = object({
    catalog_api_internal_url = string
    catalog_api_external_url = string
    admin_api_internal_url   = string
    admin_api_external_url   = string
    mysql_app_host           = string
    mysql_app_database       = string
    mysql_admin_host         = string
    mysql_admin_database     = string
    mysql_user               = string
    mysql_password           = string
    storage_account_url      = string
    storage_account_key      = string
    storage_container        = string
  })
  sensitive = true
}
