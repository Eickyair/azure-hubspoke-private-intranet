# De On-Premise a la Nube con Terraform
### Plan de migración paulatina de Northwind hacia Azure (topología Hub-Spoke privada)

> Documento tipo presentación. Cada bloque `---` equivale a una diapositiva.

---

## 1. ¿Qué es Terraform?

**Terraform** es una herramienta de **Infraestructura como Código (IaC)** creada por HashiCorp que permite **definir, versionar y desplegar** infraestructura de nube mediante archivos de texto declarativos, en lugar de hacer clics manuales en un portal.

- Se escribe en lenguaje **HCL** (*HashiCorp Configuration Language*), legible por humanos.
- Es **declarativo**: describes el *estado deseado* ("quiero esta VNet, esta base de datos, este App Service") y Terraform calcula **qué crear, modificar o destruir** para llegar a él.
- Es **multi-nube**: el mismo flujo de trabajo aplica para Azure, AWS, GCP, VMware, etc. mediante *providers*.

---

## 2. ¿Por qué Terraform para esta migración?

| Problema on-premise | Cómo lo resuelve Terraform |
|---|---|
| Configuración manual e irreproducible | Toda la infraestructura queda en **código versionado en Git** |
| "Funciona en mi servidor" | El mismo código genera ambientes **idénticos** (lab, QA, prod) |
| Cambios sin trazabilidad | Cada cambio es un *commit* + un `terraform plan` revisable |
| Miedo a romper producción | `plan` muestra el impacto **antes** de aplicar nada |
| Desmontar un entorno de prueba es tedioso | `terraform destroy` elimina todo de forma limpia |

> En este proyecto, **toda** la intranet privada de Northwind (red, bases de datos, apps, seguridad) está descrita en `terraform/` y se reconstruye con un solo `terraform apply`.

---

## 3. Conceptos clave de Terraform (glosario rápido)

- **Provider**: el conector hacia la nube. Aquí usamos `azurerm` (Azure Resource Manager).
- **Resource**: una pieza de infraestructura (`azurerm_virtual_network`, `azurerm_mysql_flexible_server`...).
- **Module**: agrupación reutilizable de recursos. Este proyecto se divide en `hub`, `spoke1`, `spoke2`, `spoke3`.
- **Variables** (`variables.tf` / `main.tfvars`): parametrizan el despliegue (regiones, tamaños, contraseñas).
- **State** (estado): el "mapa" que Terraform guarda de lo que ya existe. Aquí vive en un **backend remoto** en Azure Blob Storage, compartido y bloqueado para el equipo.
- **Flujo de trabajo**:
  ```bash
  terraform init      # descarga providers y conecta el backend
  terraform plan      # muestra el diff contra la realidad
  terraform apply     # aplica los cambios
  terraform destroy   # elimina la infraestructura
  ```

---

## 4. El punto de partida: Northwind 100% on-premise

Supongamos el estado actual de Northwind en su data center propio:

| Capa | Hoy (on-premise) | Destino (Azure) |
|---|---|---|
| **Red** | Switches/firewalls físicos, VLANs | VNets Hub-Spoke + NSGs + NVA |
| **Frontend / Intranet** | Servidores IIS/Apache con la web de catálogo y admin | App Services privados (Spoke 1) |
| **APIs** | Servicios montados en VMs internas | FastAPI en App Service (Spoke 1) |
| **Bases de datos operativas** | MySQL en servidores físicos | Azure MySQL Flexible Server privado (Spoke 2) |
| **Documentos / archivos** | File server / NAS | Storage Account + Blob privado (Spoke 2) |
| **Analítica / ETL** | Scripts en un servidor de reportes | VMs ETL + Dashboard + MySQL Analytics (Spoke 3) |
| **Acceso remoto** | VPN corporativa hacia la LAN | VPN Gateway Punto-a-Sitio + Bastion (Hub) |
| **Resolución DNS** | DNS interno corporativo | Private DNS Zones + DNS forwarder (Hub) |
| **Secretos** | Contraseñas en archivos/planillas | Azure Key Vault (Hub) |

---

## 5. La arquitectura destino (a la que llegó este proyecto)

**Topología Hub-Spoke privada, sin exposición pública de cargas de trabajo.**

```
                          ┌──────────────────────────────────────────┐
        Usuario VPN ────► │                  HUB  10.10.0.0/16        │
       (P2S 172.16.10.0)  │  VPN Gateway · Azure Bastion · WAF/AppGW  │
                          │  Private DNS Zones · Key Vault · Log Anal. │
                          │  NVA (tránsito spoke-a-spoke) · DNS fwd    │
                          └───────┬──────────────┬──────────────┬──────┘
                                  │ peering       │ peering      │ peering
                  ┌───────────────▼───┐ ┌─────────▼────────┐ ┌───▼──────────────┐
                  │ SPOKE 1  10.20/16 │ │ SPOKE 2 10.30/16 │ │ SPOKE 3 10.40/16 │
                  │ App Services priv.│ │ MySQL app/admin  │ │ MySQL analytics  │
                  │ intranet/admin/api│ │ Storage + Blob PE│ │ VM ETL · VM Dash │
                  └───────────────────┘ └──────────────────┘ └──────────────────┘
```

Características de seguridad que definen el destino:

- App Services con `public_network_access_enabled = false` + **Private Endpoint**.
- **Application Gateway privado con WAF** como único punto de entrada interno (dominios `intranet/admin/api/kpi.northwind.lab`).
- MySQL Flexible Server **solo por subnet delegada privada**.
- Storage **sin acceso público**, con Private Endpoint para Blob.
- VMs **sin IP pública**: administración exclusiva por **Azure Bastion**.
- Tráfico **spoke-a-spoke forzado por el NVA** mediante *route tables* (`next_hop = VirtualAppliance`).
- Secretos centralizados en **Key Vault**.
- Política de **etiquetado obligatorio** (`Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter`, etc.).

---

## 6. Estrategia de migración: paulatina, no "big bang"

Migrar todo de golpe es arriesgado. Proponemos un enfoque **incremental por capas**, donde on-premise y Azure **conviven** durante la transición y cada fase es reversible.

```
Fase 0  Preparación  ─►  Fase 1  Red (Hub)  ─►  Fase 2  Datos  ─►
Fase 3  Aplicaciones  ─►  Fase 4  Analítica  ─►  Fase 5  Corte  ─►  Fase 6  Cierre
```

Principio rector: **cada fase entrega valor, es validable y permite rollback** antes de avanzar a la siguiente.

---

## 7. Fase 0 — Preparación y *landing zone*

**Objetivo:** dejar lista la base para poder desplegar con Terraform de forma colaborativa.

- Crear la suscripción/tenant de Azure y definir **roles RBAC** del equipo.
- **Bootstrap del backend remoto** de estado:
  ```bash
  ./scripts/bootstrap-tfstate-backend.sh
  terraform -chdir=terraform init -backend-config="backend.hcl"
  ```
  → Storage Account + contenedor `tfstate` con *locking* nativo.
- Definir la **política de etiquetado** (`docs/politica-etiquetado.md`) y el direccionamiento IP que **no choque** con la red on-premise (10.10/10.20/10.30/10.40).
- Copiar y ajustar `main.tfvars` (región `mexicocentral`, suffixes, contraseñas, llave SSH, certificado raíz VPN).

**Resultado:** equipo capaz de hacer `terraform plan` reproducible. **Riesgo: nulo** (aún no hay cargas productivas).

---

## 8. Fase 1 — Conectividad y Hub

**Objetivo:** establecer el "cerebro" de red y el puente seguro con on-premise.

- Desplegar el **módulo `hub`**: VNet 10.10.0.0/16, Bastion, **VPN Gateway**, Application Gateway + WAF, **Private DNS Zones**, Key Vault, Log Analytics, NVA y DNS forwarder.
- Conectar la **VPN Punto-a-Sitio** (o Site-to-Site hacia el data center) para que la LAN de Northwind y Azure se vean entre sí.
- Validar resolución DNS interna (`*.northwind.lab`) y conectividad por **Bastion** a la VM de validación Windows (jumpbox).

**Resultado:** Azure y on-premise conectados; aún **sin** mover cargas. Es la fase que **habilita la coexistencia híbrida**.

---

## 9. Fase 2 — Migración de datos (Spoke 2)

**Objetivo:** llevar las bases operativas y los documentos a Azure, manteniendo on-premise como respaldo.

- Desplegar el **módulo `spoke2`**: **Azure MySQL Flexible Server** privado (bases `intranet_app` e `intranet_admin`) + **Storage Account** con Blob privado.
- **Migración de datos** con doble ventana:
  1. **Carga inicial** (`mysqldump` / Azure Database Migration Service) desde el MySQL on-premise.
  2. **Replicación / sincronización** incremental hasta el día del corte.
  3. Migrar archivos del file server al contenedor **`documents`** (azcopy).
- Validar las *route tables* que fuerzan el tránsito por el **NVA** y la conectividad privada (Private Endpoints).

**Resultado:** los datos ya viven en Azure, pero las apps siguen pudiendo apuntar on-premise. **Reversible.**

---

## 10. Fase 3 — Migración de aplicaciones (Spoke 1)

**Objetivo:** mover intranet, admin y APIs a App Services privados.

- Construir los paquetes pre-compilados:
  ```bash
  ./scripts/build-spoke1-prebuilts.sh
  ```
- Desplegar el **módulo `spoke1`**: App Service Plan + 4 App Services privados (catálogo web, admin web, API catálogo, API admin), con **VNet integration** y **Private Endpoints**.
- Apuntar las apps a la **base de datos ya migrada en Spoke 2** vía variables de entorno.
- Publicar las apps detrás del **Application Gateway/WAF** con los dominios internos `intranet/admin/api.northwind.lab`.
- **Pruebas en paralelo**: usuarios piloto acceden por VPN a la versión Azure mientras producción sigue on-premise.

**Resultado:** la intranet corre en Azure en modo *staging*, validada antes del corte definitivo.

---

## 11. Fase 4 — Analítica y ETL (Spoke 3)

**Objetivo:** reconstruir la capa de reportería e ingestión.

- Desplegar el **módulo `spoke3`**: **MySQL Analytics** privado, **VM ETL** y **VM Dashboard** (Streamlit), provisionadas con `cloud-init`, sin IP pública.
- Reapuntar los procesos ETL para que **lean de las bases operativas de Spoke 2** y escriban en `intranet_analytics`.
- Exponer el dashboard de KPIs por el App Gateway (`kpi.northwind.lab`).
- Validar permisos y conectividad por **Bastion**.

**Resultado:** la analítica deja de depender del servidor de reportes on-premise.

---

## 12. Fase 5 — Corte (*cutover*) y validación

**Objetivo:** convertir Azure en el entorno productivo.

1. **Ventana de mantenimiento** acordada (idealmente fin de semana / horario bajo).
2. Última **sincronización delta** de datos on-premise → Azure.
3. **Cambio de DNS**: los registros internos apuntan a Azure (App Gateway).
4. Ejecutar el **script de diagnóstico** `diagnostics.ps1` y la guía `guia-pruebas-jumpbox-rdp.md` para validación end-to-end.
5. **Periodo de observación** con on-premise en *standby* (rollback disponible).

**Criterio de éxito:** usuarios trabajando contra Azure sin incidencias; métricas en Log Analytics dentro de lo esperado.

---

## 13. Fase 6 — Cierre y optimización

**Objetivo:** consolidar y apagar lo viejo.

- **Decomisar** servidores on-premise una vez superado el periodo de observación.
- Mover secretos sensibles que aún viven en el *state* hacia **Key Vault** con referencias administradas.
- Endurecer producción: **listener HTTPS privado** con certificado en el App Gateway, revisión de NSGs y reglas WAF.
- Activar **alertas de costos** y revisar `CostCenter`/tags para *FinOps*.
- Documentar *runbooks* y dejar el flujo `plan → apply` como **proceso estándar de cambios** (GitOps).

**Resultado:** Northwind 100% en la nube, gobernado por código, auditable y reproducible.

---

## 14. Tabla resumen del plan

| Fase | Foco | Módulo Terraform | ¿Reversible? |
|---|---|---|---|
| 0 | Preparación / backend / tags | *(bootstrap + tfvars)* | N/A |
| 1 | Red y conectividad (Hub) | `modules/hub` | ✅ |
| 2 | Datos: MySQL + Blob | `modules/spoke2` | ✅ |
| 3 | Aplicaciones: intranet/admin/API | `modules/spoke1` | ✅ |
| 4 | Analítica: ETL + Dashboard | `modules/spoke3` | ✅ |
| 5 | Corte DNS + validación | *(operativo)* | ✅ hasta el cierre |
| 6 | Decomiso + hardening | *(operativo)* | ⛔ (punto de no retorno) |

---

## 15. Beneficios de hacerlo con Terraform

- **Reproducibilidad**: el entorno completo se levanta o se replica con un comando.
- **Reversibilidad por fases**: cada capa se aplica y se valida aislada; `destroy` selectivo si algo falla.
- **Coexistencia híbrida**: la VPN del Hub permite que on-premise y Azure trabajen juntos durante meses si hace falta.
- **Seguridad por diseño**: todo privado (sin IPs públicas en cargas), WAF, Bastion, Private Endpoints y Key Vault desde el día uno.
- **Gobierno y costos**: etiquetado obligatorio + backend de estado compartido = trazabilidad y *FinOps*.
- **Trabajo en equipo**: un solo *state* remoto con *locking*; cambios revisados como código.

---

## 16. Cierre

> Northwind no migra "moviendo servidores", sino **describiendo su infraestructura como código** y dejando que Terraform la materialice en Azure, **capa por capa**, con la posibilidad de volver atrás en cada paso hasta el corte final.

**El resultado**: una intranet privada Hub-Spoke, segura, auditable y reconstruible — la misma a la que llegó este proyecto.
