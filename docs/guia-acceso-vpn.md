# Guía rápida — Conexión VPN y acceso a las aplicaciones

## Requisitos previos

- Cliente **OpenVPN Connect** instalado en la laptop.
- Archivo de perfil VPN (`northwind-p2s.ovpn`) descargado del VPN Gateway.
- Certificado cliente (`cert-nombre.pfx`) instalado en el almacén personal del sistema.
- Certificado raíz `p2s-root-cert` instalado en *Trusted Root CAs* (para que el navegador confíe en `*.northwind.lab`).

---

## Pasos

### 1. Conectarse a la VPN P2S

Abrir OpenVPN Connect, seleccionar el perfil `northwind-p2s.ovpn` y pulsar **Connect**.
Cuando el estado cambie a **Connected**, la laptop recibirá una IP del pool `172.16.10.0/24`
y el DNS quedará apuntando al forwarder `10.10.4.50`.

```powershell
# Verificar asignación de IP VPN
ipconfig | Select-String "172.16"

# Verificar resolución DNS privada
Resolve-DnsName intranet.northwind.lab   # debe devolver 10.10.2.10
```

### 2. Intranet — Catálogo de productos

```
https://intranet.northwind.lab
```

Catálogo completo de productos con UI glassmorphism. Las imágenes se sirven desde
Blob Storage privado vía Private Endpoint. Sin VPN activa, la URL produce timeout.

### 3. Panel de Administración — Gestión de empleados

```
https://admin.northwind.lab
```

Panel de recursos humanos y operaciones conectado al MySQL Admin DB. Permite consultar,
crear y editar registros de empleados.

### 4. API REST de Catálogo

```
https://api.northwind.lab/docs
```

Interfaz Swagger de la API FastAPI. Permite probar endpoints REST (`GET /products`,
`POST /products`, etc.) que alimentan la WebApp Intranet.

### 5. Dashboard de Analítica — KPIs

```
https://kpi.northwind.lab
```

Dashboard Streamlit con gráficas de ventas, inventario y tendencias procesadas por
el ETL Runner desde el MySQL Analytics DB.

### 6. Desconectarse

Pulsar **Disconnect** en OpenVPN Connect. Los dominios `*.northwind.lab` dejarán de
resolverse de inmediato — confirma que no existe acceso fuera de la VPN.

---

> **Sin VPN:** intentar cualquiera de las URLs anteriores produce fallo de resolución DNS
> o timeout TCP. Ningún recurso tiene endpoint público.
