# Componentes de la arquitectura

## Resumen

La arquitectura propuesta mantiene el patron Hub-Spoke del caso de estudio y lo adapta a una intranet privada basada en Python y MySQL sobre Azure. El acceso de usuarios y administradores ocurre unicamente por `VPN Point-to-Site`, pasando primero por el Hub antes de alcanzar los servicios privados en los spokes.

## Hub VNet

| Servicio | Tecnologia | Funcion dentro del caso |
| --- | --- | --- |
| VPN Gateway P2S | Azure VPN Gateway | Permite que usuarios y personal de TI entren de forma privada desde una laptop real, cumpliendo el requisito de acceso privado. |
| Azure Bastion | Azure Bastion | Se usa para soporte seguro y administracion sin exponer puertos publicos. |
| Application Gateway WAF | Azure Application Gateway WAF | Centraliza la entrada HTTPS privada hacia las webapps y agrega proteccion web. |
| Private DNS Zones | Azure Private DNS | Resuelve nombres internos de App Services, MySQL y Storage por rutas privadas. |
| Key Vault | Azure Key Vault | Guarda secretos, cadenas de conexion y certificados usados por la API y las webapps. |
| Azure Monitor + Log Analytics | Azure Monitor | Consolida logs, metricas y auditoria de todos los spokes. |

## Spoke 1 - Aplicaciones

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| WebApp Intranet | Azure App Service con Django + Jinja2 | Portal principal para empleados. Permite consultar informacion interna, cargar formularios y visualizar documentos. |
| WebApp Administracion | Azure App Service con Django Admin | Portal restringido para el equipo administrativo o TI. Sirve para gestion de catalogos, revisiones operativas y soporte interno. |
| API privada | Azure App Service con FastAPI + Uvicorn | Capa de negocio desacoplada del frontend. Atiende autenticacion, consultas, operaciones CRUD y acceso controlado a datos y documentos. |

## Spoke 2 - Datos y documentos

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| MySQL App DB | Azure Database for MySQL | Base transaccional principal de la intranet. Guarda usuarios de negocio, tickets, catalogos, solicitudes y entidades operativas. |
| MySQL Admin DB | Azure Database for MySQL | Base separada para auditoria, permisos administrativos, bitacoras y configuraciones sensibles. Esta separacion reduce acoplamiento y facilita controles. |
| Storage Account Privado | Azure Storage Account + Blob Storage | Repositorio de documentos internos como evidencias, adjuntos, formatos y reportes exportados. Sin acceso publico. |
| Private Endpoints | Azure Private Endpoint | Garantiza que MySQL y Blob Storage solo se consuman por red privada. |

## Spoke 3 - Analitica

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| Proceso ETL Python | Python programado | Extrae datos desde las dos bases MySQL, los transforma y prepara tablas para analitica. |
| MySQL Analytics DB | Azure Database for MySQL | Base orientada a reporting y KPIs. Recibe informacion consolidada desde la capa ETL. |
| Dashboard interno | Streamlit | Expone indicadores y tableros para supervision administrativa sin consultar directamente las bases operativas. |

## Flujo principal de la solucion

1. Los usuarios internos se conectan por `VPN Gateway P2S` al Hub.
2. El trafico web entra por `Application Gateway WAF` y se redirige a la `WebApp Intranet` o a la `WebApp Administracion`.
3. Las webapps consumen la `API privada` en FastAPI para ejecutar la logica de negocio.
4. La API guarda y consulta informacion en `MySQL App DB`, `MySQL Admin DB` y `Storage Account Privado` usando endpoints privados.
5. El modulo ETL toma informacion de ambas bases operativas y la carga en `MySQL Analytics DB`.
6. El `Dashboard interno` consulta la base analitica para mostrar indicadores al equipo administrativo.
7. Todos los servicios envian logs y metricas a `Azure Monitor + Log Analytics`.

## Justificacion de diseno

- Se mantienen `3 spokes` para separar aplicaciones, datos y analitica.
- Existen `2 webapps` para diferenciar la experiencia de usuarios y la administracion interna.
- Existen `2 bases de datos` operativas para no mezclar transacciones del negocio con auditoria y configuracion administrativa.
- El `Storage Account` resuelve el requisito de documentos internos del caso.
- El modulo de analitica consume informacion de ambas bases y publica un dashboard sin afectar la carga transaccional.
- Todo el acceso permanece privado y alineado con el contexto Hub-Spoke del proyecto.
