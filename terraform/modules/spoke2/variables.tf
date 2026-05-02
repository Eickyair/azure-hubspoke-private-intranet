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
    address_space                  = list(string)
    mysql_subnet_prefix            = string
    private_endpoint_subnet_prefix = string
    mysql_sku_name                 = string
    mysql_version                  = string
    mysql_storage_gb               = number
    mysql_backup_retention_days    = number
    app_database_name              = string
    admin_database_name            = string
    storage_container_name         = string
  })
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "mysql_private_dns_zone_id" {
  type = string
}

variable "blob_private_dns_zone_id" {
  type = string
}

variable "mysql_administrator_login" {
  type = string
}

variable "mysql_administrator_password" {
  type      = string
  sensitive = true
}

variable "storage_account_name" {
  type = string
}
