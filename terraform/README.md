# Terraform - Hub-Spoke Private Intranet

Esta carpeta implementa la infraestructura de la practica en un unico Resource Group configurable, respetando la politica provisional de etiquetado mediante `locals.default_tags` en el modulo raiz.

## Estructura

- `main.tf`: crea el Resource Group unico y conecta los modulos.
- `variables.tf`: parametros globales, secretos y objetos por hub/spoke.
- `main.tfvars.example`: archivo principal documentado para copiar a `main.tfvars`.
- `modules/hub`: Hub VNet, subnets, Bastion, VPN Gateway, Application Gateway privado, Private DNS Zones, Key Vault y Log Analytics.
- `modules/spoke1`: VNet de aplicaciones, App Service Plan, web intranet, web admin, API FastAPI y Private Endpoints.
- `modules/spoke2`: VNet de datos, MySQL Flexible Server privado para app/admin, Storage Account privado y Blob Private Endpoint.
- `modules/spoke3`: VNet de analitica, MySQL Analytics privado, VM ETL y VM dashboard con `cloud-init`.

## Uso

```bash
cd terraform
cp main.tfvars.example main.tfvars
terraform init
terraform validate
terraform plan -var-file="main.tfvars"
```

Antes del `plan`, ajustar en `main.tfvars`:

- `resource_group_name`, si el equipo necesita otro nombre.
- `unique_suffix`, si algun App Service o Storage Account ya existe globalmente.
- `hub.vpn_root_certificate_data`, con el certificado raiz publico para VPN P2S.
- `mysql_administrator_password` y `vm_admin_ssh_public_key`.

## Codigo fuente de aplicaciones

- `../src/spoke1/webapp/main.py`: UI de intranet; consulta `/health` de la API.
- `../src/spoke1/admin/main.py`: UI admin; valida API y MySQL admin.
- `../src/spoke1/api/main.py`: API FastAPI; valida MySQL app, MySQL admin y Blob Storage.
- `../src/spoke3/etl-runner/main.py`: health endpoint del ETL privado.
- `../src/spoke3/dashboard/main.py`: dashboard Streamlit para visualizar estado de analitica.

Por defecto `spoke1.deploy_source_zip = false` porque los App Services quedan privados. Si el runner de Terraform tiene acceso al endpoint SCM/Kudu por red privada, se puede activar para empaquetar `src/spoke1/*` como zip durante el apply.

## Notas de seguridad

- Las webapps tienen `public_network_access_enabled = false` y Private Endpoint.
- El Application Gateway expone un listener privado HTTP para laboratorio y reenvia a los App Services por HTTPS. Para cierre productivo, agregar certificado y listener HTTPS privado.
- MySQL Flexible Server se despliega con acceso privado por subnet delegada.
- Storage Account se despliega sin acceso publico y con Private Endpoint para Blob.
- Las VMs de Spoke 3 no tienen IP publica y se administran por Bastion.
- Los secretos en variables sensibles siguen existiendo en el estado de Terraform; para produccion conviene moverlos a Key Vault y usar referencias administradas.
