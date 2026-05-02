variable "location" {
  description = "Region principal para todos los recursos. Debe mantenerse alineada con la politica de etiquetado."
  type        = string
  default     = "mexicocentral"
}

variable "resource_group_name" {
  description = "Nombre configurable del unico Resource Group que contiene toda la solucion."
  type        = string
  default     = "rg-privateintranet-lab-mxc"
}

variable "project_slug" {
  description = "Prefijo corto usado en nombres tecnicos. Mantener minusculas, numeros y guiones."
  type        = string
  default     = "privintra"
}

variable "environment" {
  description = "Ambiente del despliegue. Tambien alimenta el tag Environment."
  type        = string
  default     = "lab"
}

variable "unique_suffix" {
  description = "Sufijo para recursos con nombres globales como App Service y Storage Account. Cambiar si hay colision."
  type        = string
  default     = "001"
}

variable "tags" {
  description = "Tags adicionales. Se combinan con locals.default_tags sin eliminar los obligatorios."
  type        = map(string)
  default     = {}
}

variable "internal_domains" {
  description = "Dominios internos usados por Application Gateway y por las variables de entorno de las apps."
  type = object({
    intranet  = string
    admin     = string
    api       = string
    analytics = string
    zone      = string
  })
  default = {
    intranet  = "intranet.northwind.lab"
    admin     = "admin.northwind.lab"
    api       = "api.northwind.lab"
    analytics = "kpi.northwind.lab"
    zone      = "northwind.lab"
  }
}

variable "hub" {
  description = "Configuracion del modulo Hub: red, Bastion, VPN P2S, DNS privado y Application Gateway."
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
  default = {
    address_space                         = ["10.10.0.0/16"]
    gateway_subnet_prefix                 = "10.10.0.0/24"
    bastion_subnet_prefix                 = "10.10.1.0/26"
    edge_subnet_prefix                    = "10.10.2.0/24"
    shared_private_endpoint_subnet_prefix = "10.10.3.0/24"
    p2s_address_space                     = ["172.16.10.0/24"]
    enable_vpn_gateway                    = true
    vpn_root_certificate_name             = "p2s-root-cert"
    vpn_root_certificate_data             = ""
    enable_application_gateway            = true
    application_gateway_private_ip        = "10.10.2.10"
  }
}

variable "spoke1" {
  description = "Configuracion del Spoke 1 para App Services privados de intranet, admin y API."
  type = object({
    address_space                         = list(string)
    app_service_integration_subnet_prefix = string
    private_endpoint_subnet_prefix        = string
    app_service_plan_sku_name             = string
    public_network_access_enabled         = bool
    deploy_source_zip                     = bool
  })
  default = {
    address_space                         = ["10.20.0.0/16"]
    app_service_integration_subnet_prefix = "10.20.1.0/24"
    private_endpoint_subnet_prefix        = "10.20.2.0/24"
    app_service_plan_sku_name             = "B1"
    public_network_access_enabled         = false
    deploy_source_zip                     = false
  }
}

variable "spoke2" {
  description = "Configuracion del Spoke 2 para bases MySQL operativas y Blob Storage privado."
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
  default = {
    address_space                  = ["10.30.0.0/16"]
    mysql_subnet_prefix            = "10.30.1.0/24"
    private_endpoint_subnet_prefix = "10.30.2.0/24"
    mysql_sku_name                 = "B_Standard_B1ms"
    mysql_version                  = "8.0.21"
    mysql_storage_gb               = 20
    mysql_backup_retention_days    = 7
    app_database_name              = "intranet_app"
    admin_database_name            = "intranet_admin"
    storage_container_name         = "documents"
  }
}

variable "spoke3" {
  description = "Configuracion del Spoke 3 para analitica: VM ETL, VM dashboard y MySQL Analytics."
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
    mysql_storage_gb            = number
    mysql_backup_retention_days = number
    analytics_database_name     = string
  })
  default = {
    address_space               = ["10.40.0.0/16"]
    etl_subnet_prefix           = "10.40.1.0/24"
    dashboard_subnet_prefix     = "10.40.2.0/24"
    mysql_subnet_prefix         = "10.40.3.0/24"
    etl_private_ip              = "10.40.1.20"
    dashboard_private_ip        = "10.40.2.20"
    vm_size                     = "Standard_B1s"
    mysql_sku_name              = "B_Standard_B1ms"
    mysql_version               = "8.0.21"
    mysql_storage_gb            = 20
    mysql_backup_retention_days = 7
    analytics_database_name     = "intranet_analytics"
  }
}

variable "mysql_administrator_login" {
  description = "Usuario administrador para los servidores Azure Database for MySQL Flexible Server."
  type        = string
  default     = "mysqladmin"
}

variable "mysql_administrator_password" {
  description = "Password administrador para MySQL. Debe cumplir la politica de Azure y se marca como sensible."
  type        = string
  sensitive   = true
}

variable "vm_admin_username" {
  description = "Usuario administrador Linux para las VMs privadas del Spoke 3."
  type        = string
  default     = "azureuser"
}

variable "vm_admin_ssh_public_key" {
  description = "Llave publica SSH para administrar las VMs privadas por Bastion."
  type        = string
  sensitive   = true
}
