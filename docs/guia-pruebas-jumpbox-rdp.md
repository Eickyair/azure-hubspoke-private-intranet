# Guia de pruebas desde la Jumpbox por RDP

Esta guia sirve para validar, de forma grafica, que la intranet privada desplegada con Terraform funciona desde la VM Windows de pruebas ubicada en el Hub. La idea es entrar por RDP usando Azure Bastion y probar cada pieza como si fueras un usuario interno de la red privada.

## 1. Requisitos previos

Antes de probar desde la jumpbox, confirma que el despliegue termino correctamente:

```bash
terraform -chdir=terraform apply -var-file="main.tfvars"
```

Despues del apply, guarda a mano estos outputs porque los usaras durante las pruebas:

```bash
terraform -chdir=terraform output jumpbox_access
terraform -chdir=terraform output internal_urls
terraform -chdir=terraform output spoke1_default_hostnames
terraform -chdir=terraform output spoke1_private_endpoints
terraform -chdir=terraform output spoke2_mysql_fqdns
terraform -chdir=terraform output spoke3_private_ips
```

Valores esperados por defecto:

| Elemento | Valor esperado |
| --- | --- |
| VM Jumpbox | `vm-privintra-lab-001-jumpbox-01` |
| IP privada Jumpbox | `10.10.4.10` |
| Usuario RDP | Valor de `jumpbox_admin_username` |
| URL Intranet | `http://intranet.northwind.lab` |
| URL Admin | `http://admin.northwind.lab` |
| URL API liveness | `http://api.northwind.lab/live` |
| URL API health | `http://api.northwind.lab/health` |
| URL Dashboard | `http://kpi.northwind.lab:8501` |

## 2. Entrar a la Jumpbox por RDP

1. Abre el Portal de Azure.
2. Entra al Resource Group `dream-team-tf`.
3. Abre la VM `vm-privintra-lab-001-jumpbox-01`.
4. Selecciona **Connect**.
5. Selecciona **Bastion**.
6. Elige conexion por **RDP**.
7. Usa el usuario configurado en `jumpbox_admin_username`.
8. Usa la contrasena configurada en `jumpbox_admin_password`. Si dejaste el valor `REEMPLAZAR_PASSWORD_RDP_SEGURO`, Terraform usa como respaldo la contrasena de MySQL configurada en `mysql_administrator_password`.
9. Abre la sesion en el navegador.

La VM no tiene IP publica. Si intentas conectarte con Remote Desktop desde tu laptop directamente, no deberia funcionar. El acceso correcto es por Azure Bastion.

## 3. Primer chequeo dentro de Windows

Al iniciar sesion por RDP:

1. Ve al escritorio de Windows.
2. Abre el archivo `Private-Intranet-Checks.txt`.
3. Revisa que aparezcan las URLs internas y comandos de prueba.
4. Abre Microsoft Edge.
5. Prueba primero `http://api.northwind.lab/live`.
6. Luego prueba `http://api.northwind.lab/health`.

Resultado esperado para `/live`: Edge muestra un JSON simple con `service`, `status: ok` y `checked_at`. Esto confirma que Application Gateway puede llegar a la app.

Resultado esperado para `/health`: Edge muestra un JSON con `service`, `status`, `checked_at` y `dependencies`.

Si el JSON dice `status: ok`, la API puede conectarse a MySQL App, MySQL Admin y Blob Storage. Si dice `degraded`, revisa la seccion `dependencies` para ver que dependencia fallo.

## 4. Probar resolucion DNS privada

Prueba grafica rapida:

1. En Edge, abre `http://api.northwind.lab/live`.
2. Si la pagina carga, DNS privado para `api.northwind.lab` funciona y el backend esta vivo.
3. Abre `http://intranet.northwind.lab`.
4. Abre `http://admin.northwind.lab`.
5. Abre `http://kpi.northwind.lab:8501`.

Prueba opcional con PowerShell dentro de la jumpbox:

```powershell
Resolve-DnsName intranet.northwind.lab
Resolve-DnsName admin.northwind.lab
Resolve-DnsName api.northwind.lab
Resolve-DnsName kpi.northwind.lab
```

Resultado esperado:

- `intranet.northwind.lab`, `admin.northwind.lab` y `api.northwind.lab` deben resolver hacia la IP privada del Application Gateway, normalmente `10.10.2.10`.
- `kpi.northwind.lab` debe resolver hacia la IP privada del dashboard, normalmente `10.40.2.20`.

Si DNS falla, revisa en Azure Portal que la zona privada `northwind.lab` tenga registros `A` y que este enlazada a la VNet del Hub.

## 5. Probar Intranet grafica

1. En Edge, abre `http://intranet.northwind.lab`.
2. Debes ver la pantalla **Intranet privada**.
3. Revisa el bloque **Estado general**.
4. Revisa el bloque **API privada**.

Resultado esperado:

- La pagina carga sin pedir internet publico.
- El estado general aparece correcto.
- La dependencia `api-private` aparece conectada.
- La pagina se refresca sola cada cierto tiempo.

Si la pagina carga pero el estado sale con error, el frontend esta vivo pero no puede llegar a la API. En ese caso prueba directamente `http://api.northwind.lab/live` y despues `http://api.northwind.lab/health`.

## 6. Probar Admin grafico

1. En Edge, abre `http://admin.northwind.lab`.
2. Debes ver la pantalla **Administracion privada**.
3. Revisa las filas **API privada** y **MySQL admin**.

Resultado esperado:

- **API privada** debe marcar correcto.
- **MySQL admin** debe marcar correcto.

Si `API privada` falla, revisa Application Gateway y Private Endpoint de la API. Si `MySQL admin` falla, revisa el servidor `mysql-privintra-lab-001-admin` y la zona privada `privatelink.mysql.database.azure.com`.

## 7. Probar API, MySQL y Blob desde la pantalla de health

1. En Edge, abre primero `http://api.northwind.lab/live`.
2. Si responde `status: ok`, abre `http://api.northwind.lab/health`.
3. Revisa el JSON.
4. Busca estas dependencias:

| Dependencia | Que valida |
| --- | --- |
| `mysql_app` | Conexion a MySQL de la aplicacion |
| `mysql_admin` | Conexion a MySQL administrativo |
| `blob_storage` | Existencia del contenedor `documents` en Blob Storage privado |

Resultado esperado:

```json
{
  "status": "ok",
  "dependencies": {
    "mysql_app": { "status": "ok" },
    "mysql_admin": { "status": "ok" },
    "blob_storage": { "status": "ok" }
  }
}
```

Si `/live` responde pero `/health` falla, la app esta encendida pero alguna dependencia privada no esta lista. Si `blob_storage` falla con autorizacion o timeout, revisa:

- Que el Storage Account tenga Private Endpoint para Blob.
- Que exista el contenedor `documents`.
- Que la API tenga variables `STORAGE_ACCOUNT_URL`, `STORAGE_ACCOUNT_KEY` y `STORAGE_CONTAINER_NAME`.

## 8. Probar Dashboard de analitica

1. En Edge, abre `http://kpi.northwind.lab:8501`.
2. Debes ver el dashboard Streamlit **Dashboard interno de analitica**.
3. Revisa el indicador **Estado general**.
4. Revisa las tarjetas:
   - **MySQL Analytics**
   - **MySQL App Source**
   - **MySQL Admin Source**
   - **ETL Runner**

Resultado esperado:

- El dashboard carga desde la IP privada de la VM de dashboard.
- Las tarjetas de MySQL aparecen conectadas.
- El ETL Runner responde correctamente.

Si la pagina no carga, prueba en PowerShell:

```powershell
Test-NetConnection kpi.northwind.lab -Port 8501
```

Debe mostrar `TcpTestSucceeded : True`.

## 9. Probar conectividad a VMs privadas de Spoke3

Desde la jumpbox puedes validar que las VMs privadas responden en red, aunque no tengan IP publica.

En PowerShell:

```powershell
Test-NetConnection 10.40.2.20 -Port 8501
Test-NetConnection 10.40.1.20 -Port 8000
Test-NetConnection 10.40.1.20 -Port 22
```

Resultado esperado:

- Dashboard `10.40.2.20:8501`: `TcpTestSucceeded : True`.
- ETL `10.40.1.20:8000`: `TcpTestSucceeded : True`.
- SSH ETL `10.40.1.20:22`: `TcpTestSucceeded : True`.

Si los puertos fallan, revisa los NSG de Spoke3 y que los servicios hayan iniciado por `cloud-init`.

## 10. Revisar Application Gateway de forma grafica

Desde Edge dentro de la jumpbox:

1. Abre `https://portal.azure.com`.
2. Entra al Resource Group `dream-team-tf`.
3. Abre `agw-privintra-lab-001-private`.
4. En el menu lateral, abre **Backend health**.
5. Revisa los backends de intranet, admin y API.

Resultado esperado:

- Los backends deben estar en estado saludable.
- Los probes deben usar `/health`.

Si algun backend aparece unhealthy, abre el App Service correspondiente y revisa:

- **Overview**: estado `Running`.
- **Configuration**: variables de entorno.
- **Deployment Center** o logs: paquete `WEBSITE_RUN_FROM_PACKAGE`.

## 11. Revisar App Services de forma grafica

En Azure Portal, dentro del Resource Group:

1. Abre cada App Service de Spoke1.
2. Confirma que este en estado `Running`.
3. Revisa **Networking**.
4. Confirma que tenga Private Endpoint.
5. Revisa **Configuration**.

Variables importantes:

| App | Variables clave |
| --- | --- |
| Intranet | `API_BASE_URL`, `APP_PACKAGE_HASH`, `WEBSITE_RUN_FROM_PACKAGE` |
| Admin | `API_BASE_URL`, `MYSQL_ADMIN_HOST`, `MYSQL_ADMIN_DATABASE`, `APP_PACKAGE_HASH` |
| API | `MYSQL_APP_HOST`, `MYSQL_ADMIN_HOST`, `STORAGE_ACCOUNT_URL`, `STORAGE_CONTAINER_NAME` |

Resultado esperado:

- No necesitas abrir la URL publica de Azure App Service.
- La prueba real debe hacerse con los dominios internos `northwind.lab` desde la jumpbox.

## 12. Revisar MySQL de forma grafica

La forma mas rapida y visual de validar MySQL es mediante las pantallas de la API, Admin y Dashboard. Si quieres inspeccion manual con herramienta grafica:

1. En la jumpbox, descarga e instala MySQL Workbench.
2. Crea una conexion nueva.
3. Usa estos hosts desde el output `spoke2_mysql_fqdns`:
   - `mysql-privintra-lab-001-app.mysql.database.azure.com`
   - `mysql-privintra-lab-001-admin.mysql.database.azure.com`
4. Puerto: `3306`.
5. Usuario: valor de `mysql_administrator_login`.
6. Contrasena: valor de `mysql_administrator_password`.
7. Habilita SSL si la herramienta lo solicita.
8. Presiona **Test Connection**.

Resultado esperado: la conexion debe ser exitosa desde la jumpbox porque esta dentro de la red privada enrutable por peering.

## 13. Revisar Blob Storage de forma grafica

La API ya valida Blob al abrir `http://api.northwind.lab/health`. Si quieres inspeccionar el contenedor con interfaz grafica:

1. En la jumpbox, instala Microsoft Azure Storage Explorer.
2. Abre Storage Explorer.
3. Inicia sesion con la cuenta que tenga permiso al Resource Group, o conecta usando nombre de cuenta y key.
4. Busca el Storage Account de documentos creado por Terraform.
5. Abre **Blob Containers**.
6. Confirma que existe el contenedor `documents`.

Resultado esperado: el contenedor `documents` existe. Si Storage Explorer no lista el contenido, pero la API health marca `blob_storage: ok`, la conectividad de la aplicacion ya esta validada.

## 14. Orden recomendado para una demo completa

Usa este orden para probar sin saltos:

1. Entra por RDP a la jumpbox con Azure Bastion.
2. Abre `Private-Intranet-Checks.txt` en el escritorio.
3. Abre `http://api.northwind.lab/health`.
4. Abre `http://intranet.northwind.lab`.
5. Abre `http://admin.northwind.lab`.
6. Abre `http://kpi.northwind.lab:8501`.
7. En Azure Portal, revisa Backend health del Application Gateway.
8. En Azure Portal, revisa Networking de App Services y Private Endpoints.
9. Opcional: valida MySQL con MySQL Workbench.
10. Opcional: valida Blob con Azure Storage Explorer.

## 15. Guia rapida de problemas comunes

| Sintoma | Causa probable | Donde revisar |
| --- | --- | --- |
| No puedo entrar a la jumpbox | Bastion, credenciales o VM apagada | VM Jumpbox, Bastion, NSG de management |
| `api.northwind.lab` no resuelve | DNS privado incompleto | Zona `northwind.lab`, VNet links, registros A |
| `api.northwind.lab` muestra 502 | Backend unhealthy en Application Gateway | Probar `/live`, revisar Backend health y probes |
| Intranet carga pero API sale con error | API viva pero dependencia fallando | API `/live`, API `/health`, Backend health |
| API health dice MySQL error | DNS privado MySQL, credenciales o servidor no listo | MySQL Flexible Server, zona `privatelink.mysql.database.azure.com` |
| API health dice Blob error | Storage privado, contenedor o key | Storage Account, Private Endpoint Blob, contenedor `documents` |
| Dashboard no carga | VM dashboard o puerto 8501 | VM dashboard, NSG dashboard, servicio Streamlit |
| ETL aparece con error | VM ETL o puerto 8000 | VM ETL, NSG ETL, cloud-init |

## 16. Criterio de exito

La infraestructura se considera funcional para la practica cuando se cumple todo esto desde la jumpbox:

- RDP entra por Azure Bastion.
- `http://api.northwind.lab/live` devuelve `status: ok`.
- `http://api.northwind.lab/health` devuelve `status: ok` cuando MySQL y Blob estan listos.
- `http://intranet.northwind.lab` carga y muestra API conectada.
- `http://admin.northwind.lab` carga y muestra API y MySQL admin correctos.
- `http://kpi.northwind.lab:8501` carga el dashboard.
- Application Gateway muestra backends saludables.
- No se necesita IP publica en App Services, MySQL, Storage ni VMs de Spoke3.
