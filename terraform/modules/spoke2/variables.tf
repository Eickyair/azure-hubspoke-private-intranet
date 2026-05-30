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
    mysql_zone                     = string
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

variable "use_remote_gateways" {
  type = bool
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

variable "spoke1_app_service_subnet_prefix" {
  type        = string
  description = "CIDR del subnet de VNet integration de Spoke 1 (App Services). Permite MySQL inbound desde las apps."
}

variable "spoke3_etl_subnet_prefix" {
  type        = string
  description = "CIDR del subnet ETL de Spoke 3. Permite MySQL inbound desde el ETL runner."
}

variable "spoke3_dashboard_subnet_prefix" {
  type        = string
  description = "CIDR del subnet Dashboard de Spoke 3. Permite MySQL inbound desde el dashboard."
}

variable "hub_management_subnet_prefix" {
  type        = string
  description = "CIDR del hub management subnet (Jumpbox). Permite MySQL inbound para administración."
}

variable "hub_nva_ip" {
  type        = string
  description = "IP privada del NVA en hub para enrutar tráfico inter-spoke."
}

variable "spoke1_address_space" {
  type        = string
  description = "CIDR del VNet de spoke1. Se usa para UDR inter-spoke."
}

variable "spoke3_address_space" {
  type        = string
  description = "CIDR del VNet de spoke3. Se usa para UDR inter-spoke."
}
