# Archivo principal de variables para la practica Hub-Spoke.
# Copiar a main.tfvars, ajustar secretos/valores globalmente unicos y ejecutar:
# terraform plan -var-file="main.tfvars"

# General: afecta a todos los modulos y mantiene un unico Resource Group.
location            = "mexicocentral"
resource_group_name = "rg-privateintranet-lab-mxc"
project_slug        = "privintra"
environment         = "lab"
unique_suffix       = "001"

tags = {
  Owner      = "EquipoCloud"
  CostCenter = "CloudClass"
}

internal_domains = {
  zone      = "northwind.lab"
  intranet  = "intranet.northwind.lab"
  admin     = "admin.northwind.lab"
  api       = "api.northwind.lab"
  analytics = "kpi.northwind.lab"
}

# Hub: conectividad compartida, Bastion, VPN, DNS privado, Key Vault, Monitor y Application Gateway interno.
hub = {
  address_space                         = ["10.10.0.0/16"]
  gateway_subnet_prefix                 = "10.10.0.0/24"
  bastion_subnet_prefix                 = "10.10.1.0/26"
  edge_subnet_prefix                    = "10.10.2.0/24"
  shared_private_endpoint_subnet_prefix = "10.10.3.0/24"
  p2s_address_space                     = ["172.16.10.0/24"]

  # Colocar el certificado raiz publico base64 sin BEGIN/END CERTIFICATE.
  enable_vpn_gateway        = false
  vpn_root_certificate_name = "p2s-root-cert"
  vpn_root_certificate_data = "REEMPLAZAR_CON_CERTIFICADO_RAIZ_PUBLICO_BASE64"

  # Desactivado temporalmente por errores de despliegue del gateway.
  enable_application_gateway     = false
  application_gateway_private_ip = "10.10.2.10"
}

# Spoke 1: App Services privados de intranet, admin y API FastAPI.
spoke1 = {
  address_space                         = ["10.20.0.0/16"]
  app_service_integration_subnet_prefix = "10.20.1.0/24"
  private_endpoint_subnet_prefix        = "10.20.2.0/24"
  app_service_plan_sku_name             = "B1"
  public_network_access_enabled         = false
  deploy_source_zip                     = false
}

# Spoke 2: MySQL privado por subnet delegada y Blob Storage privado por Private Endpoint.
spoke2 = {
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

# Spoke 3: VM privada ETL, VM privada dashboard y MySQL Analytics privado.
spoke3 = {
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

# Secretos: no subir main.tfvars real al repositorio.
mysql_administrator_login    = "mysqladmin"
mysql_administrator_password = "Atnhb301#@thub."

vm_admin_username       = "azureuser"
vm_admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAZwlqgtzaP9sty6VelFmpP2O27aagXNNH5DwleTEVoZwNRPYd6sATShc1FAt12kHyIB1kjwW0CcNnnO5SsIoyDpDX0Y7Qf1YLMM/rpV81GO0OYzLcylvwDPRjzuLZtavJA45M687qI4R/NV0wUwfnnsLIQxY4UjzotNai59TXU/AjTl2EHkm07UCdQ96DvufXZbzbTCpTumYZoxeDGLs+zYYoipVv9f/QnhHpJYGi4bp/p6jhwBakPppeKRZhQoztPGOKYH4eWX4O/xZtduR3qViCaGUNSizOz4eOMcUgc7yptLkZBFa0b+X++t31pP+2g2IPuKn3FoqZX6kdfEd+c7wys+VeCzesqQyhxoWpuD4TnTzxu2Cno99TvRxyu4oVW6va3QD1guo68T+l2NMu+t9+/dCTsAn2entj9uLw5yu+3oGkA5ZdcChC64DED0UTO9JEz1IlsVA7Qm86r5yrLJBqKw32wWzNxdbydOV72Xjo+FSStcKNBLnY6pOLJ4n799Cn/R2B4so2Qj6wnFh4qLSdcyvp0GsY+4DPL0RZlAatK2QzG4NyQiq9ZacBIAZbNGuIsfS3FZgRTIEUxr1jwctVRAZd0N2gndaZCLWRTMx9qZb1oqWEWFZHd0vWOSGsu4bp/Z0GaEK9DBAbJzwjCeoeymzUspdnUsY4r/qnEw== azure-lab"
