# Spoke 2 - Datos y documentos

Este spoke no contiene una aplicacion Python propia en la primera iteracion. Su funcion es proveer los servicios privados que validan las apps de `src/spoke1` y `src/spoke3`:

- MySQL App DB.
- MySQL Admin DB.
- Storage Account privado con contenedor Blob.

La conectividad se valida desde `src/spoke1/api/main.py`, `src/spoke1/admin/main.py` y `src/spoke3/etl-runner/main.py` usando variables de entorno configurables.
