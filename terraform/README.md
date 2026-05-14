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
cp backend.hcl.example backend.hcl
terraform init -backend-config="backend.hcl"
terraform validate
terraform plan -var-file="main.tfvars" -lock-timeout=5m
```

## Backend remoto para trabajo en equipo

Este proyecto ya queda preparado para usar un backend remoto `azurerm` en Blob Storage. Eso permite:

- Un solo state compartido por el equipo.
- Locking nativo del state para evitar applies concurrentes.
- Colaboracion sin depender de `terraform.tfstate` local.

Bootstrap recomendado desde la raiz del repositorio:

```bash
./scripts/bootstrap-tfstate-backend.sh
terraform -chdir=terraform init -migrate-state -backend-config="backend.hcl"
```

El script crea o reutiliza un Resource Group dedicado para el backend, una Storage Account Standard LRS y el contenedor `tfstate`. Luego escribe `terraform/backend.hcl`, que esta ignorado por Git.

Si el equipo ya no tiene state local y solo necesita reconfigurar Terraform en otra maquina:

```bash
terraform -chdir=terraform init -reconfigure -backend-config="backend.hcl"
```

Si tu organizacion no permite usar account keys para el backend, activa `use_azuread_auth = true` en `backend.hcl` y asigna `Storage Blob Data Contributor` sobre la cuenta de Storage a cada integrante del equipo.

## Operacion colaborativa

Con el backend remoto ya configurado, el proyecto puede ser operado por varias personas sobre la misma infraestructura. La condicion importante es que todos usen el mismo backend y que nadie vuelva a trabajar con el state local como fuente principal.

Flujo esperado para una maquina nueva:

```bash
az login
../scripts/bootstrap-tfstate-backend.sh
terraform init -reconfigure -backend-config="backend.hcl"
```

Usa `terraform init -migrate-state -backend-config="backend.hcl"` solo cuando todavia exista un state local que deba moverse al backend remoto. Despues de esa migracion inicial, el resto del equipo debe usar `-reconfigure`.

Reglas recomendadas para colaborar sin pisarse cambios:

- No usar `-lock=false`.
- No commitear `backend.hcl`.
- Ejecutar `terraform plan` antes de `terraform apply`.
- Reconfigurar Terraform en cada maquina nueva antes de operar.
- Mantener permisos de Azure consistentes para todo el equipo sobre la suscripcion y la cuenta de Storage del backend.

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

Para ejecucion colaborativa, evita `-lock=false`. Usa siempre `-lock-timeout=5m` o el valor que tu equipo defina para esperar por el lock del state remoto.

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
