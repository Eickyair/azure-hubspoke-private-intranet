# Inicialización de Azure Database for MySQL (Flexible Server)

Este directorio contiene los scripts de esquema SQL puros que deben ser ejecutados en el servidor MySQL (PaaS) en Azure (Spoke 2) antes de encender las aplicaciones del Spoke 1.

## Contenido

- `01_intranet_schema.sql`: Estructura para el catálogo de empleados (App Admin).
- `02_catalog_schema.sql`: Estructura para el catálogo de productos (App Catalog).

## Ejecución en Azure (Desde una VM o Cloud Shell conectado a la VNet)

Al desplegar una arquitectura Hub & Spoke sin acceso a Internet, deberás ejecutar estos scripts desde una máquina o conexión VPN que tenga enrutamiento hacia la subred de la base de datos (Ej: mediante la VPN Point-to-Site configurada en el Gateway).

```bash
# Conéctate al servidor PaaS
mysql -h <tu-servidor-azure>.mysql.database.azure.com -u <usuario> -p

# Ejecuta el script de Empleados
mysql> source /ruta/hacia/01_intranet_schema.sql;

# Ejecuta el script de Productos
mysql> source /ruta/hacia/02_catalog_schema.sql;
```

Las aplicaciones en `spoke1/` insertarán automáticamente los datos de prueba (`seeds`) si las tablas están vacías gracias a la lógica implementada en SQLAlchemy.
