# azure-hubspoke-private-intranet

Private enterprise intranet platform on Azure built with a Hub-and-Spoke architecture, provisioned with Terraform and integrated with Python services, MySQL databases, private storage, analytics, and secure access through Point-to-Site VPN.

## Architecture

The following Mermaid diagrams are embedded from the source files under `docs/arquitectura`.

### General View

Source: [docs/arquitectura/arquitectura-python-mysql.mmd](docs/arquitectura/arquitectura-python-mysql.mmd)

```mermaid
%%{init: {"theme": "base", "flowchart": {"curve": "linear", "nodeSpacing": 40, "rankSpacing": 55}, "themeVariables": {"fontFamily": "Trebuchet MS", "fontSize": "14px"}} }%%
flowchart TB
    title["Diagrama 0 - Vista General\nTopologia Hub and Spokes"]:::title
    legend["Leyenda\nVerde = Hub\nAzul = Aplicaciones\nAmarillo = Datos y documentos\nMorado = Analitica\nRojo = Dependencia externa"]:::legend
    title --- legend

    subgraph topology["Topologia general"]
        direction LR
        users["Usuarios internos y TI"]:::external
        hub["Hub\nConectividad y servicios compartidos"]:::hub
        spoke1["Spoke 1\nAplicaciones privadas"]:::app
        spoke2["Spoke 2\nDatos y documentos"]:::data
        spoke3["Spoke 3\nAnalitica"]:::analytics
        mail["SMTP corporativo"]:::external
    end

    users -->|"VPN P2S"| hub
    hub -->|"Peering"| spoke1
    hub -->|"Peering"| spoke2
    hub -->|"Peering"| spoke3
    spoke1 -->|"Datos privados"| spoke2
    spoke2 -->|"Datos para KPIs"| spoke3
    spoke1 -->|"Notificaciones"| mail

    classDef title fill:#ffffff,stroke:#ffffff,color:#1f2937,font-size:20px,font-weight:bold;
    classDef legend fill:#f8fafc,stroke:#94a3b8,color:#334155;
    classDef hub fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20,stroke-width:2px;
    classDef app fill:#e3f2fd,stroke:#1565c0,color:#0d47a1,stroke-width:2px;
    classDef data fill:#fff8e1,stroke:#b28704,color:#6d4c00,stroke-width:2px;
    classDef analytics fill:#f3e5f5,stroke:#8e24aa,color:#4a148c,stroke-width:2px;
    classDef external fill:#ffebee,stroke:#c62828,color:#7f1d1d,stroke-width:2px;
```

### Hub Module

Source: [docs/arquitectura/hub-vnet-detalle.mmd](docs/arquitectura/hub-vnet-detalle.mmd)

```mermaid
%%{init: {"theme": "base", "flowchart": {"curve": "linear", "nodeSpacing": 50, "rankSpacing": 65}, "themeVariables": {"fontFamily": "Trebuchet MS", "fontSize": "13px"}} }%%
flowchart TB
    title["Diagrama 1 - Hub VNet<br/>Conectividad y servicios compartidos"]:::title
    legend["Leyenda<br/>Verde = recurso del Hub<br/>Caja gris = contenedor de red<br/>Bloque suelto = dependencia externa con color del modulo origen<br/>Rojo = servicio externo real<br/>Linea solida = trafico principal<br/>Linea punteada = control o servicio compartido"]:::legend
    title --- legend

    subgraph hubvnet["Hub VNet 10.10.0.0/16"]
        direction LR
        subgraph gwsubnet["GatewaySubnet 10.10.0.0/24"]
            direction TB
            vpn["vpn-gw-hub-01<br/>Azure VPN Gateway<br/>Pool P2S 172.16.10.0/24"]:::hub
        end

        subgraph bastionsubnet["AzureBastionSubnet 10.10.1.0/26"]
            direction TB
            bastion["bastion-hub-01<br/>Azure Bastion<br/>IP privada 10.10.1.4"]:::hub
        end

        subgraph edgesubnet["EdgeSubnet 10.10.2.0/24"]
            direction TB
            agw["agw-hub-private<br/>Application Gateway WAF<br/>IP privada 10.10.2.10<br/>Hosts: intranet.northwind.lab / admin.northwind.lab"]:::hub
        end

        shared["Servicios compartidos del Hub<br/>Private DNS Zones<br/>privatelink.azurewebsites.net<br/>privatelink.mysql.database.azure.com<br/>privatelink.blob.core.windows.net<br/>Key Vault: kv-intranet.privatelink.vaultcore.azure.net<br/>Azure Monitor + Log Analytics"]:::hub
    end

    laptops["Laptops del equipo<br/>Clientes P2S"]:::external
    spoke1["[Spoke 1] WebApps privadas"]:::app
    spoke2["[Spoke 2] Datos privados"]:::data
    spoke3["[Spoke 3] ETL y dashboard"]:::analytics

    laptops -->|"SSL VPN :443 / IKEv2"| vpn
    vpn -->|"Rutas privadas por peering"| spoke1
    vpn -->|"Rutas privadas por peering"| spoke2
    vpn -->|"Rutas privadas por peering"| spoke3
    agw -->|"HTTPS :443"| spoke1
    shared -.->|"DNS+KV :443"| spoke1
    shared -.->|"DNS :53/443"| spoke2
    shared -.->|"DNS+Mon :443"| spoke3
    bastion -.->|"Mgmt :443"| spoke3

    spoke1 ~~~ spoke2
    spoke2 ~~~ spoke3

    style hubvnet fill:#f8fafc,stroke:#2e7d32,stroke-width:2px;
    style gwsubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;
    style bastionsubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;
    style edgesubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;

    classDef title fill:#ffffff,stroke:#ffffff,color:#1f2937,font-size:20px,font-weight:bold;
    classDef legend fill:#f8fafc,stroke:#94a3b8,color:#334155;
    classDef hub fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20,stroke-width:2px;
    classDef app fill:#e3f2fd,stroke:#1565c0,color:#0d47a1,stroke-width:2px;
    classDef data fill:#fff8e1,stroke:#b28704,color:#6d4c00,stroke-width:2px;
    classDef analytics fill:#f3e5f5,stroke:#8e24aa,color:#4a148c,stroke-width:2px;
    classDef external fill:#ffebee,stroke:#c62828,color:#7f1d1d,stroke-width:2px;
```

### Spoke 1 - Applications

Source: [docs/arquitectura/spoke1-aplicaciones-detalle.mmd](docs/arquitectura/spoke1-aplicaciones-detalle.mmd)

```mermaid
%%{init: {"theme": "base", "flowchart": {"curve": "linear", "nodeSpacing": 52, "rankSpacing": 68}, "themeVariables": {"fontFamily": "Trebuchet MS", "fontSize": "13px"}} }%%
flowchart TB
    title["Diagrama 2 - Spoke 1 / Aplicaciones<br/>Web privada y API"]:::title
    legend["Leyenda<br/>Azul = recurso del modulo<br/>Caja gris = contenedor de red<br/>Bloque suelto = dependencia externa con color del modulo origen<br/>Rojo = servicio externo real<br/>Linea solida = trafico principal<br/>Linea punteada = control o resolucion"]:::legend
    title --- legend

    subgraph spoke1["Spoke 1 VNet 10.20.0.0/16"]
        direction LR
        subgraph appsubnet["AppServiceIntegrationSubnet 10.20.1.0/24"]
            direction TB
            portal["web-intranet<br/>Django + Jinja2<br/>https://intranet.northwind.lab"]:::app
            adminapp["web-admin<br/>Django Admin<br/>https://admin.northwind.lab"]:::app
            api["api-private<br/>FastAPI + Uvicorn<br/>https://api.northwind.lab"]:::app
        end

        subgraph pesubnet["PrivateEndpointSubnet 10.20.2.0/24"]
            direction TB
            peportal["pe-intranet-web<br/>10.20.2.10<br/>intranet-web.privatelink.azurewebsites.net"]:::app
            peadmin["pe-admin-web<br/>10.20.2.11<br/>admin-web.privatelink.azurewebsites.net"]:::app
            peapi["pe-api-web<br/>10.20.2.12<br/>api-web.privatelink.azurewebsites.net"]:::app
        end
    end

    agw["[Hub] agw-hub-private<br/>10.10.2.10"]:::hub
    kv["[Hub] kv-intranet<br/>kv-intranet.privatelink.vaultcore.azure.net"]:::hub
    dbapp["[Spoke 2] mysql-app-db<br/>mysql-app.privatelink.mysql.database.azure.com"]:::data
    dbadmin["[Spoke 2] mysql-admin-db<br/>mysql-admin.privatelink.mysql.database.azure.com"]:::data
    blob["[Spoke 2] stnorthwinddocs<br/>stnorthwinddocs.privatelink.blob.core.windows.net"]:::data
    smtp["[Ext] smtp.northwind.example"]:::external

    agw -->|"HTTPS :443"| peportal
    agw -->|"HTTPS :443"| peadmin
    peportal -.->|"PrivLink"| portal
    peadmin -.->|"PrivLink"| adminapp
    peapi -.->|"PrivLink"| api
    portal -->|"HTTPS :443"| peapi
    adminapp -->|"HTTPS :443"| peapi
    api -->|"MySQL :3306"| dbapp
    adminapp -->|"MySQL :3306"| dbadmin
    api -->|"MySQL :3306"| dbadmin
    api -->|"HTTPS :443"| blob
    api -.->|"Secrets :443"| kv
    api -->|"SMTP :587"| smtp

    agw ~~~ kv
    kv ~~~ dbapp
    dbapp ~~~ dbadmin
    dbadmin ~~~ blob
    blob ~~~ smtp

    style spoke1 fill:#f8fafc,stroke:#1565c0,stroke-width:2px;
    style appsubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;
    style pesubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;

    classDef title fill:#ffffff,stroke:#ffffff,color:#1f2937,font-size:20px,font-weight:bold;
    classDef legend fill:#f8fafc,stroke:#94a3b8,color:#334155;
    classDef hub fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20,stroke-width:2px;
    classDef app fill:#e3f2fd,stroke:#1565c0,color:#0d47a1,stroke-width:2px;
    classDef data fill:#fff8e1,stroke:#b28704,color:#6d4c00,stroke-width:2px;
    classDef analytics fill:#f3e5f5,stroke:#8e24aa,color:#4a148c,stroke-width:2px;
    classDef external fill:#ffebee,stroke:#c62828,color:#7f1d1d,stroke-width:2px;
```

### Spoke 2 - Data and Documents

Source: [docs/arquitectura/spoke2-datos-detalle.mmd](docs/arquitectura/spoke2-datos-detalle.mmd)

```mermaid
%%{init: {"theme": "base", "flowchart": {"curve": "linear", "nodeSpacing": 55, "rankSpacing": 72}, "themeVariables": {"fontFamily": "Trebuchet MS", "fontSize": "13px"}} }%%
flowchart TB
    title["Diagrama 3 - Spoke 2 / Datos y documentos<br/>MySQL y Blob Storage privados"]:::title
    legend["Leyenda<br/>Amarillo = recurso del modulo<br/>Caja gris = contenedor de red<br/>Bloque suelto = dependencia externa con color del modulo origen<br/>Rojo = servicio externo real<br/>Linea solida = trafico principal<br/>Linea punteada = private link o resolucion"]:::legend
    title --- legend

    subgraph spoke2["Spoke 2 VNet 10.30.0.0/16"]
        direction LR
        subgraph pesubnet["PrivateEndpointSubnet 10.30.1.0/24"]
            direction TB
            pemysqlapp["pe-mysql-app<br/>10.30.1.10<br/>mysql-app.privatelink.mysql.database.azure.com"]:::data
            pemysqladmin["pe-mysql-admin<br/>10.30.1.11<br/>mysql-admin.privatelink.mysql.database.azure.com"]:::data
            peblob["pe-blob-docs<br/>10.30.1.12<br/>stnorthwinddocs.privatelink.blob.core.windows.net"]:::data
        end

        dataservices["Servicios PaaS privados<br/>MySQL App DB<br/>MySQL Admin DB<br/>Storage Account / Blob"]:::data
    end

    api["[Spoke 1] api-private"]:::app
    etl["[Spoke 3] etl-runner-01"]:::analytics
    dns["[Hub] Private DNS Zones"]:::hub

    api -->|"MySQL :3306"| pemysqlapp
    api -->|"MySQL :3306"| pemysqladmin
    api -->|"HTTPS :443"| peblob
    etl -->|"MySQL :3306"| pemysqlapp
    etl -->|"MySQL :3306"| pemysqladmin
    pemysqlapp -.->|"PrivLink"| dataservices
    pemysqladmin -.->|"PrivLink"| dataservices
    peblob -.->|"PrivLink"| dataservices
    dns -.->|"DNS :53"| pemysqlapp
    dns -.->|"DNS :53"| pemysqladmin
    dns -.->|"DNS :53"| peblob

    api ~~~ etl
    etl ~~~ dns

    style spoke2 fill:#f8fafc,stroke:#b28704,stroke-width:2px;
    style pesubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;

    classDef title fill:#ffffff,stroke:#ffffff,color:#1f2937,font-size:20px,font-weight:bold;
    classDef legend fill:#f8fafc,stroke:#94a3b8,color:#334155;
    classDef hub fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20,stroke-width:2px;
    classDef app fill:#e3f2fd,stroke:#1565c0,color:#0d47a1,stroke-width:2px;
    classDef data fill:#fff8e1,stroke:#b28704,color:#6d4c00,stroke-width:2px;
    classDef analytics fill:#f3e5f5,stroke:#8e24aa,color:#4a148c,stroke-width:2px;
    classDef external fill:#ffebee,stroke:#c62828,color:#7f1d1d,stroke-width:2px;
```

### Spoke 3 - Analytics

Source: [docs/arquitectura/spoke3-analitica-detalle.mmd](docs/arquitectura/spoke3-analitica-detalle.mmd)

```mermaid
%%{init: {"theme": "base", "flowchart": {"curve": "linear", "nodeSpacing": 55, "rankSpacing": 72}, "themeVariables": {"fontFamily": "Trebuchet MS", "fontSize": "13px"}} }%%
flowchart TB
    title["Diagrama 4 - Spoke 3 / Analitica<br/>ETL y dashboard interno"]:::title
    legend["Leyenda<br/>Morado = recurso del modulo<br/>Caja gris = contenedor de red<br/>Bloque suelto = dependencia externa con color del modulo origen<br/>Rojo = servicio externo real<br/>Linea solida = trafico principal<br/>Linea punteada = observabilidad o gestion"]:::legend
    title --- legend

    subgraph spoke3["Spoke 3 VNet 10.40.0.0/16"]
        direction LR
        subgraph etlsubnet["EtlSubnet 10.40.1.0/24"]
            direction TB
            etl["etl-runner-01<br/>Python ETL<br/>10.40.1.20"]:::analytics
        end

        subgraph dashboardsubnet["DashboardSubnet 10.40.2.0/24"]
            direction TB
            dashboard["dashboard-kpi-01<br/>Streamlit<br/>10.40.2.20<br/>https://kpi.northwind.lab"]:::analytics
        end

        subgraph pesubnet["PrivateEndpointSubnet 10.40.3.0/24"]
            direction TB
            peanalytics["pe-mysql-analytics<br/>10.40.3.10<br/>mysql-analytics.privatelink.mysql.database.azure.com"]:::analytics
        end

        analyticsdb["MySQL Analytics DB<br/>mysql-analytics.privatelink.mysql.database.azure.com"]:::analytics
    end

    dbapp["[Spoke 2] mysql-app-db"]:::data
    dbadmin["[Spoke 2] mysql-admin-db"]:::data
    vpnusers["[Hub] Usuarios por VPN P2S"]:::hub
    monitor["[Hub] Azure Monitor + Log Analytics"]:::hub
    bastion["[Hub] Azure Bastion"]:::hub

    etl -->|"MySQL :3306"| dbapp
    etl -->|"MySQL :3306"| dbadmin
    etl -->|"MySQL :3306"| peanalytics
    peanalytics -.->|"PrivLink"| analyticsdb
    dashboard -->|"MySQL :3306"| peanalytics
    vpnusers -->|"HTTPS :443"| dashboard
    etl -.->|"Logs :443"| monitor
    dashboard -.->|"Logs :443"| monitor
    bastion -.->|"Mgmt :443"| etl
    bastion -.->|"Mgmt :443"| dashboard

    dbapp ~~~ dbadmin
    dbadmin ~~~ vpnusers
    vpnusers ~~~ monitor
    monitor ~~~ bastion

    style spoke3 fill:#f8fafc,stroke:#8e24aa,stroke-width:2px;
    style etlsubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;
    style dashboardsubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;
    style pesubnet fill:#f1f5f9,stroke:#94a3b8,stroke-width:1px;

    classDef title fill:#ffffff,stroke:#ffffff,color:#1f2937,font-size:20px,font-weight:bold;
    classDef legend fill:#f8fafc,stroke:#94a3b8,color:#334155;
    classDef hub fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20,stroke-width:2px;
    classDef app fill:#e3f2fd,stroke:#1565c0,color:#0d47a1,stroke-width:2px;
    classDef data fill:#fff8e1,stroke:#b28704,color:#6d4c00,stroke-width:2px;
    classDef analytics fill:#f3e5f5,stroke:#8e24aa,color:#4a148c,stroke-width:2px;
    classDef external fill:#ffebee,stroke:#c62828,color:#7f1d1d,stroke-width:2px;
```

### Diagram Sources

- [General view](docs/arquitectura/arquitectura-python-mysql.mmd)
- [Hub module](docs/arquitectura/hub-vnet-detalle.mmd)
- [Spoke 1 - Applications](docs/arquitectura/spoke1-aplicaciones-detalle.mmd)
- [Spoke 2 - Data and documents](docs/arquitectura/spoke2-datos-detalle.mmd)
- [Spoke 3 - Analytics](docs/arquitectura/spoke3-analitica-detalle.mmd)
- [Diagram guide](docs/arquitectura/diagramas-jerarquicos.md)
