# Quickstart
## 1. Que contiene este proyecto

El repositorio implementa una intranet privada en Azure con arquitectura Hub-Spoke.

- Hub: conectividad privada, Bastion, VPN, DNS privado, observabilidad y entrada central.
- Spoke 1: aplicaciones Python para catalogo y administracion.
- Spoke 2: bases MySQL privadas y Blob Storage privado.
- Spoke 3: ETL privado y dashboard interno.

## 2. Stack y tecnologias

### Infraestructura y operaciones

- Terraform para infraestructura Azure.
- Azure CLI para autenticacion, diagnosticos y operaciones post-deploy.
- Bash para scripts de automatizacion del laboratorio.
- `jq`, `awk`, `sed`, `base64`, `zip` y `sha256sum` como utilidades usadas por los scripts.

### Aplicaciones

- Python 3.11 como runtime objetivo para los paquetes de App Service.
- FastAPI + Uvicorn para APIs y webapps de Spoke 1.
- Jinja2 + archivos estaticos para las interfaces web.
- SQLAlchemy + PyMySQL para acceso a MySQL.
- Azure Storage Blob SDK para documentos e imagenes.
- Streamlit para el dashboard de Spoke 3.

### Datos

- Azure Database for MySQL Flexible Server para App DB, Admin DB y Analytics DB.
- Azure Blob Storage privado para documentos e imagenes.
- SQLite local como fallback de desarrollo para las APIs de Spoke 1 cuando no configuras MySQL.

## 3. Estructura rapida del repositorio

```text
.
├── docker-compose.yml
├── quickstart.md
├── docs/
│   ├── guia-pruebas-jumpbox-rdp.md
│   └── arquitectura/
├── scripts/
│   ├── bootstrap-tfstate-backend.sh
│   ├── build-spoke1-prebuilts.sh
│   ├── deploy-full.sh
│   ├── destroy-infra.sh
│   ├── postdeploy-db.sh
│   └── postdeploy-storage-images.sh
├── src/
│   ├── spoke1/
│   │   ├── admin/
│   │   │   ├── api/
│   │   │   └── webapp/
│   │   └── catalog/
│   │       ├── api/
│   │       └── webapp/
│   ├── spoke2/
│   │   ├── db_init/
│   │   └── list-images.txt
│   └── spoke3/
│       ├── dashboard/
│       └── etl-runner/
└── terraform/
    ├── main.tf
    ├── main.tfvars.example
    ├── backend.hcl.example
    └── modules/
```

## 4. Scripts que vas a usar primero

| Script | Para que sirve | Cuando usarlo |
| --- | --- | --- |
| `./scripts/bootstrap-tfstate-backend.sh` | Crea o reutiliza el backend remoto de Terraform y escribe `terraform/backend.hcl`. | La primera vez en una maquina nueva. |
| `./scripts/build-spoke1-prebuilts.sh` | Genera ZIPs con dependencias Python para App Services de Spoke 1. | Si cambias codigo de `src/spoke1` antes de `plan` o `apply`. |
| `./scripts/deploy-full.sh` | Orquesta build, `terraform init`, `validate`, `plan`, `apply`, diagnosticos y postdeploy. | Flujo recomendado para desplegar todo el laboratorio. |
| `./scripts/postdeploy-db.sh` | Carga esquemas y datos demo en MySQL usando la jumpbox. | Despues de aplicar infraestructura. |
| `./scripts/postdeploy-storage-images.sh` | Sube imagenes al Blob privado y actualiza MySQL. | Despues de poblar datos demo. |
| `./scripts/destroy-infra.sh` | Ejecuta el flujo controlado de destruccion con Terraform. | Cuando vayas a desmontar el laboratorio. |

## 5. Preparar el entorno local

Ejecuta todo desde la raiz del repositorio.

### 5.1 Herramientas base

En Linux, valida primero que tengas las herramientas necesarias:

```bash
git --version
python3 --version
pip --version
docker --version
docker compose version
az version
terraform version
jq --version
zip -v | head -n 1
```

Si vas a operar infraestructura o scripts de postdeploy, tambien necesitas que existan estas utilidades:

```bash
command -v awk
command -v sed
command -v base64
command -v sha256sum
```

### 5.2 Clonar y entrar al repo

```bash
git clone <URL_DEL_REPOSITORIO>
cd azure-hubspoke-private-intranet
```

### 5.3 Crear un virtual environment opcional para trabajo local

No hay un `requirements.txt` global. Lo normal es crear un entorno por servicio o uno temporal para pruebas rapidas.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
```

Si quieres correr un servicio especifico fuera de Docker, instala sus dependencias desde su carpeta.

Ejemplo para Catalog API:

```bash
cd src/spoke1/catalog/api
python -m pip install -r requirements.txt
cd ../../../..
```

### 5.4 Autenticar Azure CLI

Para Terraform, scripts de backend y postdeploy, primero autentica Azure:

```bash
az login
az account show --output table
az account set --subscription "<SUBSCRIPTION_ID>"
```

## 6. Levantar servicios en local

Tienes dos formas utiles de trabajar localmente.

### Opcion A. Levantar Spoke 1 con Docker Compose

Esto es lo mas rapido para revisar UI, endpoints y conectividad entre contenedores.

```bash
docker compose up --build
```

Servicios expuestos por defecto:

- `http://localhost:8000`: admin API.
- `http://localhost:8001`: admin webapp.
- `http://localhost:8002`: catalog API.
- `http://localhost:8003`: catalog webapp.

Verifica salud rapidamente:

```bash
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
```

Detener contenedores:

```bash
docker compose down
```

### Opcion B. Correr servicios Python sin Docker

Las APIs de Spoke 1 pueden arrancar sin MySQL ni Blob reales. Si no defines `MYSQL_*` ni `STORAGE_*`, usan SQLite local y storage mockeado.

Catalog API:

```bash
cd src/spoke1/catalog/api
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8002
```

Catalog webapp:

```bash
cd src/spoke1/catalog/webapp
python -m pip install -r requirements.txt
API_INTERNAL_URL=http://localhost:8002 \
API_EXTERNAL_URL=http://localhost:8002/api \
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8003
```

Admin API:

```bash
cd src/spoke1/admin/api
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Admin webapp:

```bash
cd src/spoke1/admin/webapp
python -m pip install -r requirements.txt
API_INTERNAL_URL=http://localhost:8000 \
API_EXTERNAL_URL=http://localhost:8000/api \
CATALOG_API_EXTERNAL_URL=http://localhost:8002/api \
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

Spoke 3 ETL runner:

```bash
cd src/spoke3/etl-runner
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8010
```

Spoke 3 dashboard:

```bash
cd src/spoke3/dashboard
python -m pip install -r requirements.txt
ETL_HEALTH_URL=http://localhost:8010/health \
streamlit run main.py --server.port 8501
```

## 7. Configurar Terraform en una maquina nueva

### 7.1 Crear archivos locales de trabajo

```bash
cp terraform/main.tfvars.example terraform/main.tfvars
cp terraform/backend.hcl.example terraform/backend.hcl
```

Edita `terraform/main.tfvars` y revisa como minimo:

- `location`
- `resource_group_name`
- `project_slug`
- `environment`
- `unique_suffix`
- `mysql_administrator_password`
- `vm_admin_ssh_public_key`
- `jumpbox_admin_password`
- `hub.vpn_root_certificate_data` si vas a habilitar VPN P2S

### 7.2 Crear o reutilizar backend remoto compartido

El equipo debe usar state remoto, no state local.

```bash
chmod +x scripts/bootstrap-tfstate-backend.sh
./scripts/bootstrap-tfstate-backend.sh
```

Si el state se migra por primera vez desde tu maquina:

```bash
terraform -chdir=terraform init -migrate-state -backend-config="backend.hcl"
```

Si el state ya existe y solo estas configurando una maquina nueva:

```bash
terraform -chdir=terraform init -reconfigure -backend-config="backend.hcl"
```

### 7.3 Validar que ya estas apuntando al state remoto

```bash
terraform -chdir=terraform state list | head
```

## 8. Flujo Terraform recomendado para el equipo

### Opcion A. Flujo completo orquestado

Este es el camino recomendado si vas a desplegar infraestructura y postdeploy de una sola vez.

```bash
chmod +x scripts/deploy-full.sh
./scripts/deploy-full.sh --backend-config terraform/backend.hcl
```

Para aplicar de verdad:

```bash
./scripts/deploy-full.sh --backend-config terraform/backend.hcl --auto-approve --db-task reset-demo
```

Variantes utiles:

```bash
./scripts/deploy-full.sh --backend-config terraform/backend.hcl --plan-file tfplan-lab
./scripts/deploy-full.sh --backend-config terraform/backend.hcl --auto-approve --skip-diagnostics
./scripts/deploy-full.sh --backend-config terraform/backend.hcl --auto-approve --skip-images --db-task all
```

### Opcion B. Flujo manual de Terraform

Usa este flujo cuando quieras revisar cambios de infraestructura con mas control.

```bash
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan \
  -var-file="main.tfvars" \
  -input=false \
  -lock-timeout=5m \
  -out=tfplan-change
terraform -chdir=terraform show tfplan-change
```

Aplicar el plan guardado:

```bash
terraform -chdir=terraform apply \
  -input=false \
  -lock-timeout=5m \
  tfplan-change
```

Ver outputs relevantes:

```bash
terraform -chdir=terraform output
terraform -chdir=terraform output -json | jq '{resource_group_name, jumpbox_access, spoke2_mysql_fqdns, internal_urls}'
```

## 9. Postdeploy despues de Terraform

Poblar bases de datos demo:

```bash
chmod +x scripts/postdeploy-db.sh
./scripts/postdeploy-db.sh all
./scripts/postdeploy-db.sh verify
```

Resetear y volver a cargar datos demo:

```bash
./scripts/postdeploy-db.sh reset-demo
./scripts/postdeploy-db.sh verify
```

Subir imagenes al Blob privado:

```bash
chmod +x scripts/postdeploy-storage-images.sh
./scripts/postdeploy-storage-images.sh
```

## 10. Reglas de trabajo en equipo con Terraform

- No uses `-lock=false`.
- No subas `terraform/backend.hcl` ni archivos con secretos.
- Antes de `apply`, corre `git pull` y vuelve a ejecutar `terraform plan`.
- Si cambias codigo de `src/spoke1`, regenera prebuilts antes del `plan` con `./scripts/build-spoke1-prebuilts.sh`.
- Si otra persona esta aplicando cambios, espera el lock remoto del state en lugar de forzar operaciones.

## 11. Destruir infraestructura

```bash
chmod +x scripts/destroy-infra.sh
./scripts/destroy-infra.sh --backend-config terraform/backend.hcl
./scripts/destroy-infra.sh --backend-config terraform/backend.hcl --auto-approve --wait
```

## 12. Primeros pasos sugeridos para una persona nueva

1. Leer `README.md` y `docs/arquitectura/componentes-arquitectura.md` para entender la solucion.
2. Levantar `docker compose up --build` para familiarizarse con Spoke 1.
3. Crear `terraform/main.tfvars` desde el ejemplo y autenticar Azure CLI.
4. Configurar `terraform/backend.hcl` con `./scripts/bootstrap-tfstate-backend.sh`.
5. Ejecutar `./scripts/deploy-full.sh --backend-config terraform/backend.hcl` primero sin `--auto-approve`.

## 13. Documentacion relacionada

- `README.md`: despliegue completo y diagramas.
- `terraform/README.md`: detalle de la carpeta Terraform.
- `docs/arquitectura/componentes-arquitectura.md`: componentes y tecnologias.
- `docs/guia-pruebas-jumpbox-rdp.md`: validaciones manuales desde la jumpbox.
