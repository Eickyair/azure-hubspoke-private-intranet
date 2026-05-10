---
trigger: always_on
---


# Práctica Final de Laboratorio

## Implementación de arquitectura Hub and Spoke en Azure con acceso privado mediante VPN Point-to-Site

## 1. Objetivo general

Diseñar e implementar en Azure una arquitectura **Hub and Spoke** segura, donde:

* El **Hub** concentre servicios de conectividad y administración.
* El **Spoke** aloje una aplicación web privada.
* Se incorpore:

  * Base de datos privada (IaaS o PaaS)
  * Almacenamiento privado
* Acceso desde laptops mediante **VPN Point-to-Site (P2S)**.
* Estimación de costos con Azure Pricing Calculator.

## 2. Escenario

La empresa ficticia **Northwind Distribución** desea migrar una intranet a Azure:

* Uso interno (personal de la empresa)
* Duración estimada: **3 años**
* Puede operar:

  * 24x7 o
  * Horario laboral (optimización de costos)

### Restricciones clave

* ❌ No publicar la app en internet
* ❌ Storage no público
* ✔ Acceso controlado
* ✔ Preparado para expansión (nuevos spokes)

### Requerimientos estratégicos

* Arquitectura Hub and Spoke
* Acceso por VPN P2S
* Aplicación accesible solo en red privada
* Análisis financiero:

  * Pago por uso
  * Instancias reservadas
  * Estrategia mixta

## 3. Objetivos específicos

* Implementar arquitectura Hub and Spoke
* Configurar:

  * Hub con Bastion y VPN Gateway
  * Spoke con aplicación privada
* Publicar aplicación **sin internet**
* Integrar:

  * Base de datos privada
  * Blob Storage o Azure Files privado
* Configurar VPN P2S
* Estimar costos
* Definir nomenclatura y tags
* Analizar costo a 3 años
* Documentar solución

## 4. Requerimientos obligatorios

### 4.1 Arquitectura

* Hub VNet:

  * Azure Bastion
  * VPN Gateway
  * Subnets:

    * AzureBastionSubnet
    * GatewaySubnet
* Spoke VNet:

  * Subnet de aplicación
* VNet Peering (Hub ↔ Spoke)

### 4.2 Aplicación web privada

* VM o App Service
* ❌ No accesible desde internet
* ✔ Acceso vía VPN

### 4.3 Base de datos y Storage

* Base de datos privada (IaaS o PaaS)
* Integración con:

  * Base de datos
  * Storage (Blob o Files)
* ❌ Sin exposición pública

### 4.4 Acceso administrativo

* Uso de Azure Bastion
* ❌ No RDP (3389) abierto
* ❌ No SSH (22) abierto
* ❌ No IP pública en VM

### 4.5 VPN Point-to-Site

* Configurada en VPN Gateway
* Conexión real desde laptop
* Acceso a recursos privados

### 4.6 Costos

* Azure Pricing Calculator
* Incluir:

  * VM
  * Discos
  * App Service
  * Base de datos
  * VPN Gateway
  * Bastion
  * Storage
* Análisis:

  * Costo mensual
  * Región
  * Supuestos
  * Estrategia a 3 años

### 4.7 Nomenclatura y tags

Tags mínimos:

* Project
* Environment
* Owner
* CostCenter / Area
* Workload / Criticality

## 5. Prerrequisitos

* Suscripción de Azure
* Azure Portal
* Laptop con VPN
* Conocimientos básicos de:

  * VNets
  * Subredes
  * VMs / App Service
  * Storage
  * Bastion
  * VPN Gateway

## 6. Recursos mínimos

* Resource Group(s)
* Hub VNet + Spoke VNet
* Peering
* Bastion + VPN Gateway
* Aplicación privada
* Base de datos
* Storage privado
* Calculadora de costos
* Tags y nomenclatura

## 7. Pasos sugeridos

### Fase 1: Diseño

* Arquitectura lógica
* Direccionamiento IP
* Elección de:

  * VM o App Service
  * DB IaaS o PaaS
  * Blob o Files
* Flujo de acceso
* Tags y naming

### Fase 2: Red base

* Crear Resource Groups
* Crear VNets
* Configurar peering
* Aplicar tags

### Fase 3: Hub

* Bastion
* VPN Gateway
* Configurar P2S
* Probar conexión

### Fase 4: Spoke

* VM sin IP pública o App Service privado
* Validar acceso

### Fase 5: DB y Storage

* DB privada
* Storage privado
* Validar conectividad

### Fase 6: Integración

* App ↔ DB
* App ↔ Storage
* Validar funcionamiento

### Fase 7: Costeo

* Azure Pricing Calculator
* Ajustar recursos
* Documentar costos

### Fase 8: Validación

* VPN funcionando
* App accesible
* Sin exposición pública
* Tags correctos

## 8. Evidencias

* Arquitectura desplegada
* VPN funcional
* App privada funcionando
* DB y Storage conectados
* Tags aplicados
* Costos documentados

## 9. Entregables

* Diagrama de arquitectura
* Documento técnico (3–6 páginas)
* Evidencias (capturas)
* Calculadora de costos
* Demo (10–15 min)

**Extras:**

* +5% automatización VM
* +5% despliegue con GitHub

## 11. Restricciones

* ❌ No app pública
* ❌ No IP pública en VM
* ❌ No puertos abiertos
* ❌ No DB/Storage públicos
* ❌ No omitir peering
* ❌ No simular VPN

## 12. Extras

### Automatización (VM)

* Encendido/apagado 8x5

### App Service + GitHub

* CI/CD automático

## 13. Sugerencias

### Opción VM

* Linux + Nginx / Apache
* Windows + IIS

### Opción App Service

* HTML / Node / .NET
* Acceso privado

## 14. Preguntas guía

* ¿Por qué Hub and Spoke?
* ¿Para qué sirve Bastion?
* ¿Diferencia VPN vs Bastion?
* ¿Cómo garantizan privacidad?
* ¿Qué optimizaciones harían?
* ¿Qué componentes son más costosos?

## 15. Versión corta

* Hub:

  * Bastion
  * VPN Gateway
  * VPN P2S
* Spoke:

  * App privada
  * DB privada
  * Storage privado
* ✔ Acceso por VPN
* ✔ Sin exposición pública
* ✔ Costos analizados (3 años)

## Desarrollo Backend (FastAPI - Spoke 1 & 2)

Asume el rol de un Desarrollador Backend Python experto. Tu tarea principal es construir la API de la intranet en FastAPI.

* Tu código debe conectarse a una instancia de MySQL PaaS (Spoke 2) y a un Azure Blob Storage utilizando exclusivamente el SDK de Azure y conectores de Python, asumiendo que el tráfico fluye por una red privada.
* Estructura el código en capas limpias (controladores, servicios, repositorios de datos).
* Implementa manejo de errores robusto para conexiones de red (ej. *timeouts* en caso de que el VNet Peering falle).
* Mantén las respuestas de la API en formato JSON claro, validando la entrada y salida con Pydantic.

## Data Engineering & Analítica (ETL - Spoke 3)

Asume el rol de un Data Engineer enfocado en la construcción de pipelines de datos escalables. Estás a cargo de la integración entre la base de datos transaccional (MySQL PaaS) y el entorno analítico.

* Diseña scripts de Python optimizados para grandes volúmenes de datos (Big Data).
* Propón arquitecturas ETL (Extract, Transform, Load) que puedan correr de forma automatizada y segura dentro de la intranet privada.
* Sugiere el uso eficiente de Azure Blob Storage no solo como repositorio de archivos estáticos, sino como un posible Data Lake interno.
* Tu código debe estar diseñado para ejecutarse en entornos productivos industriales, priorizando el rendimiento, la observabilidad de los datos y el bajo consumo de memoria.
