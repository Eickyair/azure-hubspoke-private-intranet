# azure-hubspoke-private-intranet

Private enterprise intranet platform on Azure built with a Hub-and-Spoke architecture, provisioned with Terraform and integrated with Python services, MySQL databases, private storage, analytics, and secure access through Point-to-Site VPN.

## Architecture

```mermaid
graph LR
    user["Usuarios internos<br/>VPN corporativa"]
    admins["Equipo TI<br/>Administradores"]

    subgraph hubspoke["Azure Hub-Spoke para intranet privada"]
        subgraph hub["Hub VNet"]
            vpn["VPN Gateway P2S<br/>acceso privado"]
            bastion["Azure Bastion<br/>soporte seguro"]
            agw["Application Gateway WAF<br/>entrada privada HTTPS"]
            dns["Private DNS Zones<br/>resolucion interna"]
            kv["Azure Key Vault<br/>secretos y certificados"]
            mon["Azure Monitor + Log Analytics<br/>observabilidad central"]
        end

        subgraph spoke1["Spoke 1 - Aplicaciones"]
            portal["WebApp Intranet<br/>Azure App Service<br/>Django + Jinja2"]
            adminapp["WebApp Administracion<br/>Azure App Service<br/>Django Admin"]
            api["API privada<br/>Azure App Service<br/>FastAPI + Uvicorn"]
        end

        subgraph spoke2["Spoke 2 - Datos y documentos"]
            dbapp["MySQL App DB<br/>usuarios, tickets, catalogos"]
            dbadmin["MySQL Admin DB<br/>auditoria, permisos, bitacora"]
            docs["Storage Account Privado<br/>Blob Storage de documentos"]
            pe["Private Endpoints<br/>MySQL + Storage"]
        end

        subgraph spoke3["Spoke 3 - Analitica"]
            etl["Proceso ETL Python<br/>extraccion y consolidacion"]
            dbanalytics["MySQL Analytics DB<br/>modelo de reportes"]
            dashboard["Dashboard interno<br/>Streamlit"]
        end
    end

    subgraph external["Servicios externos controlados"]
        mail["SMTP corporativo<br/>notificaciones"]
    end

    user -->|"Conecta por VPN"| vpn
    admins -->|"Conecta por VPN"| vpn
    vpn -->|"Ingreso al Hub"| agw
    bastion -.->|"Soporte operativo"| spoke1
    bastion -.->|"Soporte operativo"| spoke2
    bastion -.->|"Soporte operativo"| spoke3
    dns -.->|"DNS privado"| spoke1
    dns -.->|"DNS privado"| spoke2
    dns -.->|"DNS privado"| spoke3
    hub -->|"Peering"| spoke1
    hub -->|"Peering"| spoke2
    hub -->|"Peering"| spoke3

    agw -->|"HTTPS intranet"| portal
    agw -->|"HTTPS administracion"| adminapp
    portal -->|"Consume API"| api
    adminapp -->|"Administra procesos"| api

    api -->|"CRUD operacional"| dbapp
    api -->|"Auditoria y roles"| dbadmin
    api -->|"Carga y consulta archivos"| docs
    api -->|"Secretos de conexion"| kv
    api -->|"Envia correos"| mail
    adminapp -->|"Consulta permisos"| dbadmin

    pe -->|"Acceso privado"| dbapp
    pe -->|"Acceso privado"| dbadmin
    pe -->|"Acceso privado"| docs
    spoke2 -->|"Replica privada"| etl
    dbapp -->|"Datos operativos"| etl
    dbadmin -->|"Datos de auditoria"| etl
    etl -->|"Carga analitica"| dbanalytics
    dashboard -->|"Lee KPIs"| dbanalytics
    admins -->|"Consulta reportes"| dashboard

    portal -.->|"Logs web"| mon
    adminapp -.->|"Logs admin"| mon
    api -.->|"Metricas API"| mon
    dbapp -.->|"Auditoria BD"| mon
    dbadmin -.->|"Auditoria BD"| mon
    dashboard -.->|"Uso dashboard"| mon

    classDef hub fill:#dff3e3,stroke:#2f6b3b,color:#17361d;
    classDef app fill:#d9ecff,stroke:#2d6ea3,color:#16344b;
    classDef data fill:#fff1bf,stroke:#8d6f00,color:#4a3a00;
    classDef analytics fill:#f6defb,stroke:#8a3fa0,color:#4a1d57;
    classDef external fill:#ffdede,stroke:#a64b4b,color:#522121;

    class vpn,bastion,agw,dns,kv,mon hub;
    class portal,adminapp,api app;
    class dbapp,dbadmin,docs,pe data;
    class etl,dbanalytics,dashboard analytics;
    class mail external;
```
