# Inicializacion de Azure Database for MySQL (Flexible Server)

Este directorio contiene scripts SQL idempotentes para preparar las bases privadas de Spoke 2 despues de crear la infraestructura con Terraform.

## Contenido

- `01_intranet_schema.sql`: esquema de empleados para la base `spoke2.admin_database_name`.
- `02_catalog_schema.sql`: esquema de productos para la base `spoke2.app_database_name`.
- `03_mock_data_employees.sql`: datos demo de 50 empleados para la base admin.
- `04_catalog_seed.sql`: datos demo de productos.

## Ejecucion post-deploy

La forma recomendada en este laboratorio es ejecutar las tareas desde la jumpbox privada mediante Azure Run Command:

```bash
./scripts/postdeploy-db.sh schema
./scripts/postdeploy-db.sh seed
./scripts/postdeploy-db.sh verify
```

Tambien se puede ejecutar todo en una sola llamada:

```bash
./scripts/postdeploy-db.sh all
```

El runner local lee los outputs de Terraform, toma los FQDN privados de MySQL y ejecuta la tarea en la VM jumpbox, que si tiene ruta y DNS privado hacia las bases.
