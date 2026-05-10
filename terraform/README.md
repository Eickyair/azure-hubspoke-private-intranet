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
- `hub.vpn_root_certificate_data`, con el certificado raiz publico para VPN P2S si se habilita la VPN.
- `mysql_administrator_password` y `vm_admin_ssh_public_key`.
- `jumpbox_admin_password`, si se desea un password distinto al de MySQL para la VM Windows de validacion.

## Codigo fuente de aplicaciones

- `../src/spoke1/catalog/webapp/main.py`: UI de intranet (catalogo); consulta `/health` de la API de catalogo.
- `../src/spoke1/admin/webapp/main.py`: UI admin; valida la API admin y MySQL admin.
- `../src/spoke1/catalog/api/main.py`: API FastAPI del catalogo; valida MySQL app y Blob Storage.
- `../src/spoke1/admin/api/main.py`: API FastAPI admin; valida MySQL admin y Blob Storage.
- `../src/spoke3/etl-runner/main.py`: health endpoint del ETL privado.
- `../src/spoke3/dashboard/main.py`: dashboard Streamlit para visualizar estado de analitica.

El despliegue de `src/spoke1/*` usa paquetes ZIP preconstruidos con dependencias Python 3.11 dentro de `packages/`, publicados en el Storage Account de paquetes y consumidos con `WEBSITE_RUN_FROM_PACKAGE`. El startup agrega `/home/site/wwwroot/packages` a `PYTHONPATH` y ejecuta Uvicorn, evitando tanto `pip install` en cada arranque como builds Oryx lentos en Kudu.

Antes de ejecutar `terraform plan` o `terraform apply`, generar los paquetes preconstruidos:

```bash
../scripts/build-spoke1-prebuilts.sh
```

El script crea los ZIP en `terraform/.terraform-build/prebuilt/` con nombres `webapp-prebuilt-<hash>.zip`, `admin-prebuilt-<hash>.zip` y `api-prebuilt-<hash>.zip`. Esa carpeta es un artefacto local ignorado por Git; Terraform toma esos archivos y los publica en el Storage Account de paquetes.

Se agrega tambien una VM Windows privada en el Hub para validacion manual por Azure Bastion. La VM deja en el escritorio un archivo `Private-Intranet-Checks.txt` con URLs internas y comandos utiles, e instala Azure CLI para usar la identidad administrada asignada al Resource Group.

## Notas de seguridad

- Las webapps tienen `public_network_access_enabled = false` y Private Endpoint.
- El Application Gateway expone un listener privado HTTP para laboratorio y reenvia a los App Services por HTTPS. Para cierre productivo, agregar certificado y listener HTTPS privado.
- MySQL Flexible Server se despliega con acceso privado por subnet delegada.
- Storage Account se despliega sin acceso publico y con Private Endpoint para Blob.
- Las VMs de Spoke 3 no tienen IP publica y se administran por Bastion.
- La VM Windows de validacion en el Hub tampoco tiene IP publica; el acceso se hace por Azure Bastion con RDP privado.
- Los secretos en variables sensibles siguen existiendo en el estado de Terraform; para produccion conviene moverlos a Key Vault y usar referencias administradas.
