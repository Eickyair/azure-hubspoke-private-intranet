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
    deploy_source_zip                     = bool
  })
}

variable "app_names" {
  type = object({
    webapp = string
    admin  = string
    api    = string
  })
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "app_service_private_dns_zone_id" {
  type = string
}

variable "source_paths" {
  type = object({
    webapp = string
    admin  = string
    api    = string
  })
}

variable "app_environment" {
  type = object({
    api_base_url         = string
    mysql_app_host       = string
    mysql_app_database   = string
    mysql_admin_host     = string
    mysql_admin_database = string
    mysql_user           = string
    mysql_password       = string
    storage_account_url  = string
    storage_account_key  = string
    storage_container    = string
  })
  sensitive = true
}
