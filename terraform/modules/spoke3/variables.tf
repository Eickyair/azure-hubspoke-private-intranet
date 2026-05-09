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
    address_space               = list(string)
    etl_subnet_prefix           = string
    dashboard_subnet_prefix     = string
    mysql_subnet_prefix         = string
    etl_private_ip              = string
    dashboard_private_ip        = string
    vm_size                     = string
    mysql_sku_name              = string
    mysql_version               = string
    mysql_zone                  = string
    mysql_storage_gb            = number
    mysql_backup_retention_days = number
    analytics_database_name     = string
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

variable "mysql_private_dns_zone_id" {
  type = string
}

variable "mysql_administrator_login" {
  type = string
}

variable "mysql_administrator_password" {
  type      = string
  sensitive = true
}

variable "vm_admin_username" {
  type = string
}

variable "vm_admin_ssh_public_key" {
  type      = string
  sensitive = true
}

variable "source_paths" {
  type = object({
    dashboard  = string
    etl_runner = string
  })
}

variable "upstream_databases" {
  type = object({
    app_host       = string
    app_database   = string
    admin_host     = string
    admin_database = string
  })
}

variable "hub_bastion_subnet_prefix" {
  type        = string
  description = "CIDR del AzureBastionSubnet del Hub. Permite SSH inbound a las VMs solo desde Bastion."
}

variable "hub_management_subnet_prefix" {
  type        = string
  description = "CIDR del hub management subnet (Jumpbox). Permite acceso API/Streamlit inbound para pruebas."
}
