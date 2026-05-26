# Componentes de la arquitectura

## Resumen

La arquitectura propuesta mantiene el patron Hub-Spoke del caso de estudio y lo adapta a una intranet privada basada en Python y MySQL sobre Azure. El acceso de usuarios y administradores ocurre unicamente por `VPN Point-to-Site`, pasando primero por el Hub antes de alcanzar los servicios privados en los spokes.

## Hub VNet

| Servicio | Tecnologia | Funcion dentro del caso |
| --- | --- | --- |
| VPN Gateway P2S | Azure VPN Gateway (VpnGw1AZ) | Permite que usuarios y personal de TI entren de forma privada desde una laptop real, cumpliendo el requisito de acceso privado. |
| Azure Bastion | Azure Bastion | Se usa para soporte seguro y administracion sin exponer puertos publicos. |
| Application Gateway WAF | Azure Application Gateway WAF | Centraliza la entrada HTTPS privada hacia las webapps y agrega proteccion web. |
| Private DNS Zones | Azure Private DNS | Resuelve nombres internos de App Services, MySQL y Storage por rutas privadas. |
| Key Vault | Azure Key Vault | Guarda secretos, cadenas de conexion y certificados usados por las APIs y las webapps. |
| Azure Monitor + Log Analytics | Azure Monitor | Consolida logs, metricas y auditoria de todos los spokes. |
| Jumpbox VM | Windows Server VM (Standard_B4s_v2) | Permite conectividad directa para administracion y pruebas internas de los recursos privados. |
| DNS Forwarder VM | Linux VM con `dnsmasq` (10.10.4.50) | Reenvia peticiones DNS desde la subred VPN (172.16.10.0/24) hacia el resolvedor de Azure (168.63.129.16) para posibilitar la resolucion de dominios privados. |

## Spoke 1 - Aplicaciones

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| WebApp Intranet | Azure App Service con Django + Jinja2 | Portal principal para empleados. Permite consultar informacion interna, cargar formularios y visualizar documentos. |
| WebApp Administracion | Azure App Service con Django Admin | Portal restringido para el equipo administrativo o TI. Sirve para gestion de catalogos, revisiones operativas y soporte interno. |
| API privada (Catalog) | Azure App Service con FastAPI + Uvicorn | Capa de negocio desacoplada del frontend de intranet. Atiende autenticacion, consultas y operaciones CRUD operativas. |
| API privada (Admin) | Azure App Service con FastAPI + Uvicorn | Capa de negocio desacoplada dedicada a la webapp de administracion, aislando flujos y datos de auditoria. |
| Private Endpoints Web | Azure Private Endpoint + Private DNS | Publica la intranet, el portal administrativo y ambas APIs solo por red privada de forma segura. |

## Spoke 2 - Datos y documentos

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| MySQL App DB | Azure Database for MySQL Flexible | Base transaccional principal de la intranet. Guarda usuarios de negocio, tickets, catalogos, solicitudes y entidades operativas. |
| MySQL Admin DB | Azure Database for MySQL Flexible | Base separada para auditoria, permisos administrativos, bitacoras y configuraciones sensibles. Esta separacion reduce acoplamiento y facilita controles. |
| Storage Account Privado | Azure Storage Account + Blob Storage | Repositorio de documentos internos como evidencias, adjuntos, formatos y reportes exportados. Sin acceso publico. |
| Integracion de Red y Endpoints | Subnet delegada y Private Endpoints | Los servidores MySQL Flexible se integran directamente a su subnet delegada (10.30.1.0/24), mientras que el Storage Account se expone a traves de Private Endpoint (10.30.2.0/24). |

## Spoke 3 - Analitica

| Servicio | Tecnologia | Funcion |
| --- | --- | --- |
| Proceso ETL Python | VM Linux privada con Python programado | Extrae datos desde las dos bases MySQL, los transforma y prepara tablas para analitica. Se administra de forma segura mediante Bastion o SSH. |
| MySQL Analytics DB | Azure Database for MySQL Flexible | Base orientada a reporting y KPIs. Recibe informacion consolidada desde la capa ETL. Se integra directamente en su subnet delegada (10.40.3.0/24). |
| Dashboard interno | VM Linux privada con Streamlit (Puerto 8501) | Expone indicadores y tableros para supervision administrativa sin consultar directamente las bases operativas. |

## Flujo principal de la solucion

1. Los usuarios internos se conectan por `VPN Gateway P2S` al Hub. Las peticiones DNS de los clientes VPN se resuelven a traves del **DNS Forwarder VM** (`10.10.4.50`), el cual reenvia consultas a `168.63.129.16`.
2. El trafico web entra por `Application Gateway WAF` y se redirige a la `WebApp Intranet` o a la `WebApp Administracion`.
3. Las webapps consumen sus respectivas APIs privadas (`API Catalog` y `API Admin`) en FastAPI para ejecutar la logica de negocio de forma aislada.
4. Las APIs guardan y consultan informacion en `MySQL App DB`, `MySQL Admin DB` y `Storage Account Privado` usando la red privada.
5. El modulo ETL, ejecutado en una VM privada del Spoke 3, toma informacion de ambas bases operativas y la carga en `MySQL Analytics DB` mediante consultas privadas a traves de los peerings.
6. El `Dashboard interno`, publicado en una VM privada con Streamlit en el Spoke 3, consulta la base analitica para mostrar indicadores al equipo administrativo.
7. Todos los servicios envian logs y metricas a `Azure Monitor + Log Analytics`.

## Justificacion de diseno

- Se mantienen `3 spokes` para separar aplicaciones, datos y analitica.
- Existen `2 webapps` y `2 APIs` dedicadas para diferenciar y aislar la experiencia de usuarios generales de la administracion interna.
- Existen `2 bases de datos` operativas para no mezclar transacciones del negocio con auditoria y configuracion administrativa.
- El `Storage Account` resuelve el requisito de documentos internos del caso.
- El modulo de analitica consume informacion de ambas bases y publica un dashboard sin afectar la carga transaccional.
- Todo el acceso permanece privado y alineado con el contexto Hub-Spoke del proyecto.

