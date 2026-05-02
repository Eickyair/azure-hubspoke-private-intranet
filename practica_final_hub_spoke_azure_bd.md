# Práctica Final de Laboratorio

## Implementación de arquitectura Hub and Spoke en Azure con acceso privado mediante VPN Point-to-Site

### Cómputo en la nube con Azure

| Campo | Valor |
| --- | --- |
| Materia | Cómputo en la nube con Azure |
| Modalidad | Trabajo en equipo |
| Tipo de actividad | Práctica final de laboratorio |
| Duración sugerida | 2 a 3 sesiones de laboratorio más tiempo adicional de preparación |

## 1. Objetivo general

Diseñar e implementar en Azure una arquitectura Hub and Spoke segura, en la que el Hub concentre servicios de conectividad y administración, el Spoke aloje una aplicación web privada, la solución incorpore una base de datos privada en modalidad IaaS o PaaS, la aplicación consuma almacenamiento en Azure también de forma privada, los integrantes del equipo puedan acceder al entorno desde sus laptops mediante una VPN Point-to-Site (P2S), y el equipo estime el costo de la solución mediante una calculadora pública de Azure.

## 2. Escenario

La empresa ficticia Northwind Distribución desea migrar una intranet corporativa a Azure. Esta intranet será utilizada por personal interno para consultar información operativa, documentos, algunos componentes básicos de negocio y datos almacenados en una base de datos corporativa.

La empresa estima que esta intranet deberá permanecer en operación al menos durante los próximos 3 años, por lo que la solución no debe pensarse solo como un laboratorio temporal, sino como una primera base de una plataforma con cierta permanencia.

El uso de la aplicación podrá variar según el diseño de cada equipo: algunos podrían justificar disponibilidad 24x7, mientras que otros podrían proponer operación en horario laboral, apagando ciertos recursos fuera de horario para optimizar costo.

Por lineamientos de seguridad, la aplicación no debe publicarse a internet, el almacenamiento no debe ser público, el acceso administrativo debe hacerse de forma controlada, y el entorno debe quedar listo para futuras expansiones a nuevos spokes.

La empresa ha solicitado una arquitectura Hub and Spoke, donde el Hub centralice servicios compartidos, el Spoke contenga la carga de trabajo, el acceso desde laptops ocurra usando VPN Point-to-Site, la aplicación solo pueda consultarse desde la red privada, y la solución quede documentada también desde la perspectiva de costos, gobierno de recursos y operación.

Además, la dirección de tecnología quiere que cada equipo analice financieramente su propuesta, considerando que la intranet durará 3 años, para decidir si conviene más un esquema de pago por uso, una estrategia de instancias reservadas o una combinación de ambas, de acuerdo con su diseño técnico y patrón de uso esperado.

## 3. Objetivos específicos

- Implementar una arquitectura Hub and Spoke funcional en Azure.
- Configurar un Hub con Azure Bastion y VPN Gateway.
- Configurar un Spoke con una aplicación web privada.
- Publicar una aplicación sin exponerla a internet.
- Incorporar una base de datos privada, ya sea en modalidad IaaS o PaaS, y conectarla con la aplicación.
- Conectar la aplicación a Blob Storage o Azure Files de forma privada.
- Configurar una VPN P2S y conectarse desde una laptop al entorno.
- Estimar el costo mensual de la solución con Azure Pricing Calculator.
- Aplicar una estrategia consistente de nomenclatura y tags.
- Analizar el costo de la solución considerando una operación prevista de 3 años, evaluando si conviene más pago por uso, instancias reservadas o una estrategia mixta.
- Documentar y defender técnicamente el diseño implementado.

> Página 1

## 4. Requerimientos obligatorios

### 4.1 Arquitectura Hub and Spoke

- Hub VNet con Azure Bastion, VPN Gateway, AzureBastionSubnet y GatewaySubnet.
- Spoke VNet con la carga de aplicación, una subnet para la aplicación y conectividad hacia almacenamiento privado.
- VNet Peering entre Hub y Spoke.

### 4.2 Aplicación web privada

- Desplegar el sitio web en el Spoke usando una VM con servidor web o un Azure App Service.
- La aplicación no debe ser pública ni estar accesible libremente desde internet.
- El acceso debe ser privado, por ejemplo desde laptops conectadas por VPN P2S.

### 4.3 Base de datos y consumo de almacenamiento privado

- La solución debe incluir una base de datos privada, ya sea en modalidad IaaS o PaaS.
- La aplicación deberá conectarse tanto a la base de datos como a Azure Blob Storage o Azure Files.
- La base de datos y el Storage no deben quedar expuestos públicamente.
- El equipo debe demostrar cómo la aplicación accede a la base de datos y al Storage.

### 4.4 Acceso administrativo seguro

- Azure Bastion para administrar VMs, si usan VM.
- No se permite RDP abierto a internet.
- No se permite SSH abierto a internet.
- No se permite IP pública en la VM de aplicación.

### 4.5 VPN Point-to-Site obligatoria

- Implementar una VPN P2S en el VPN Gateway del Hub.
- Demostrar que al menos una laptop del equipo se conecta a Azure por VPN.
- Demostrar que desde esa laptop es posible acceder a recursos privados del entorno.

### 4.6 Calculadora pública obligatoria

- Entregar una Azure Pricing Calculator pública o evidencia equivalente compartible con el costo estimado de la solución.
- Incluir, según aplique: Virtual Machines, Managed Disks, App Service o App Service Plan, base de datos IaaS o PaaS, VPN Gateway, Azure Bastion, Public IPs, Storage Account y otros componentes relevantes.
- Incluir costo mensual estimado, supuestos usados, región seleccionada y justificación básica del dimensionamiento.
- Agregar un análisis de costo a 3 años y justificar si la estrategia hace más sentido con pago por uso, instancias reservadas o una estrategia mixta.

### 4.7 Estrategia obligatoria de nomenclatura y tags

- Todos los recursos deben seguir una convención de nombres consistente.
- Cada recurso deberá incluir como mínimo los tags: Project, Environment, Owner, CostCenter o Area, y Workload o Criticality.
- El equipo deberá explicar por qué eligió esa nomenclatura y cómo los tags ayudarían a operar, gobernar o costear la solución.

> Página 2

## 5. Prerrequisitos

- Una suscripción de Azure con permisos suficientes para crear recursos.
- Acceso a Azure Portal.
- Al menos una laptop por equipo para conectarse por VPN P2S.
- Navegador web actualizado.
- Conocimiento básico de VNets, subredes, peering, VMs o App Service, Storage Account, Bastion, VPN Gateway, Azure Pricing Calculator, tags y nomenclatura.

## 6. Recursos mínimos esperados

- Resource Group o los necesarios según el diseño.
- Hub VNet y Spoke VNet.
- Peering Hub-to-Spoke y Spoke-to-Hub.
- Azure Bastion y VPN Gateway.
- Configuración Point-to-Site.
- Aplicación web privada.
- Base de datos privada en modalidad IaaS o PaaS.
- Storage Account privado o restringido.
- Método funcional de conexión de la aplicación a la base de datos y al Storage.
- Calculadora de costos pública.
- Tags y nomenclatura consistentes.

## 7. Pasos sugeridos de implementación

### Fase 1. Diseño de arquitectura

- Definir el diseño lógico Hub and Spoke.
- Elegir direccionamiento IP de Hub y Spoke.
- Elegir si la aplicación será VM con servidor web o App Service.
- Elegir si la base de datos será IaaS o PaaS.
- Elegir si consumirán Blob Storage o Azure Files.
- Diseñar el flujo de acceso desde laptop hacia la app, y desde la app hacia la base de datos y el Storage.
- Definir la estrategia de nomenclatura y de tags.

### Fase 2. Despliegue de red base

- Crear el Resource Group o los grupos de recursos.
- Crear la Hub VNet con AzureBastionSubnet y GatewaySubnet.
- Crear la Spoke VNet y la subnet de aplicación.
- Configurar VNet Peering entre Hub y Spoke.
- Aplicar nomenclatura y tags desde el inicio.

### Fase 3. Implementación del Hub

- Desplegar Azure Bastion en el Hub.
- Desplegar VPN Gateway en el Hub.
- Configurar la VPN Point-to-Site.
- Instalar y configurar el cliente VPN en al menos una laptop.
- Probar conectividad desde la laptop.

### Fase 4. Implementación del Spoke

- Si eligen VM: crear una VM sin IP pública, instalar servidor web y validar acceso administrativo por Bastion.
- Si eligen App Service: crear App Service Plan, crear App Service, configurar acceso privado o restringido y validar que no quede expuesto públicamente.

> Página 3

### Fase 5. Implementación de base de datos y Storage

- Implementar una base de datos privada, ya sea IaaS o PaaS, con acceso restringido.
- Validar conectividad entre la aplicación y la base de datos.
- Crear una Storage Account.
- Elegir Blob Storage o Azure Files.
- Configurar acceso privado o acceso restringido por red.
- Crear el contenido que será consumido por la aplicación.

### Fase 6. Integración aplicación-base de datos-Storage

- Configurar la aplicación para conectarse y consumir la base de datos.
- Configurar la aplicación para leer o consumir el Storage.
- Validar que la aplicación consulta o utiliza información desde la base de datos.
- Validar que la app muestre o lea contenido desde Blob o Files.
- Confirmar que el acceso no depende de endpoints públicos abiertos.

### Fase 7. Costeo de la solución

- Abrir Azure Pricing Calculator.
- Agregar los componentes implementados.
- Ajustar cantidades, SKUs y supuestos.
- Guardar o compartir la calculadora.
- Documentar costo mensual, componentes incluidos, supuestos, oportunidades de optimización y estrategia de costo a 3 años.

### Fase 8. Validación final

- Probar conectividad VPN P2S desde laptop.
- Probar acceso al recurso privado.
- Validar funcionamiento de la app, conectividad a la base de datos y consumo del Storage.
- Validar ausencia de exposición pública indebida.
- Validar convención de nombres, tags aplicados y costo estimado de la solución.

## 8. Evidencias requeridas

- Arquitectura desplegada: Hub VNet, Spoke VNet y peering.
- Hub: Azure Bastion, VPN Gateway y configuración P2S.
- Conectividad: cliente VPN conectado desde laptop y prueba de acceso a recurso privado.
- Aplicación: sitio funcionando y validación de acceso privado.
- Base de datos: recurso creado, configuración privada o restringida y prueba de conectividad desde la aplicación.
- Storage: recurso creado, configuración privada o restringida y prueba de consumo desde la app.
- Gobierno: captura de nomenclatura aplicada y tags en recursos.
- Costos: calculadora pública o evidencia compartible, costo mensual total, principales componentes costosos y análisis de costo a 3 años.

## 9. Entregables

- Diagrama de arquitectura con Hub, Spoke, peering, Bastion, VPN Gateway, laptop conectada por P2S, aplicación, Storage y flujo de acceso.
- Documento técnico de 3 a 6 páginas con objetivo, diseño de red, direccionamiento IP, servicios implementados, explicación de la VPN P2S, explicación de por qué la app no es pública, explicación de por qué la base de datos no es pública, explicación de por qué el Storage no es público, estrategia de nomenclatura, estrategia de tags, resumen de costos, análisis de costo a 3 años, evidencia de funcionamiento y problemas encontrados con su solución.
- Evidencias: capturas claras del entorno y pruebas.
- Calculadora pública: enlace compartible o evidencia exportada.
- Presentación o demo de 10 a 15 minutos.

> Página 4

## 10. Criterios de validación

- Existe arquitectura Hub and Spoke.
- Bastion está implementado en el Hub.
- VPN Gateway está implementado en el Hub.
- Existe VPN P2S funcional.
- Una laptop logra conectarse al entorno.
- La app está en el Spoke y no es pública.
- La base de datos no es pública y la aplicación logra conectarse a ella.
- El Storage no es público.
- La app consume Blob o Files.
- Existe calculadora de costos.
- Existe estrategia de tags y nomenclatura.
- Existe documentación y defensa técnica.

## 11. Restricciones

- No se permite publicar libremente la aplicación en internet.
- No se permite usar IP pública en la VM de aplicación.
- No se permite abrir 3389 o 22 a internet.
- No se permite dejar la base de datos o el Storage abiertos al público sin control.
- No se permite omitir el peering Hub-Spoke.
- No se permite simular la VPN sin conectarse realmente desde laptop.
- No se permite entregar recursos sin tags o con nombres inconsistentes.

## 12. Extras / puntos adicionales

### Extra 1. Automatización de encendido y apagado 8x5

- Si usan una VM para la aplicación o administración, obtendrán puntos extra si implementan automatización para encendido y apagado en horario 8x5, o al menos autoapagado fuera del horario laboral.
- Deben demostrar cómo funciona, qué horario configuraron, qué recursos se ven impactados y cómo esa decisión influye en su estrategia de costos frente a reserva o pago por uso.

### Extra 2. Despliegue automatizado con GitHub para App Service

- Si usan App Service, obtendrán puntos extra si configuran despliegue automatizado desde GitHub.
- Deben demostrar que el código fuente está en un repositorio de GitHub, que el App Service está conectado al repositorio, que existe un flujo de despliegue automático o integrado, y que al realizar un cambio en el código y enviarlo al repositorio la aplicación se actualiza en Azure.
- Formas válidas: Deployment Center, GitHub Actions u otro mecanismo equivalente.

## 13. Sugerencias de implementación

- Opción con VM: VM Linux con Nginx o Apache, o VM Windows con IIS, con página HTML simple, consumo de imagen desde Blob o lectura de archivo desde Azure Files, y conexión a una base de datos en VM o PaaS.
- Opción con App Service: aplicación simple HTML, Node o .NET, acceso privado, lectura de contenido desde Blob Storage y validación de acceso solo por red privada, además de conexión a una base de datos PaaS o IaaS.
- Ejemplo de tags: Project=NorthwindLab, Environment=Lab, Owner=Equipo3, CostCenter=CloudClass, Workload=WebPrivate.
- Ejemplo de nomenclatura: rg-northwind-lab-hub, vnet-northwind-hub, vnet-northwind-spoke-web, vm-northwind-web-01, stnorthwindlab01.

## 14. Preguntas guía para la defensa

- ¿Por qué usaron Hub and Spoke?
- ¿Por qué Bastion está en el Hub?
- ¿Qué función cumple el VPN Gateway?
- ¿Qué diferencia existe entre Bastion y VPN P2S?
- ¿Cómo demuestran que la app no es pública?
- ¿Cómo demuestran que la base de datos y el Storage no son públicos?
- ¿Cómo validaron el acceso desde la laptop?
- ¿Qué rol juega el peering?
- ¿Qué valor aportan los tags y la nomenclatura?
- ¿Por qué eligieron una base de datos IaaS o PaaS y qué ventajas tenía esa decisión?
- ¿Qué componentes fueron los más costosos en la calculadora?
- ¿Cómo optimizarían el costo?
- ¿La intranet operará durante 3 años. Por qué su estrategia de costo fue pago por uso, reservación o una mezcla?
- ¿Si decidieron apagar la VM fuera de horario, cómo cambia eso la conveniencia de reservar capacidad?
- ¿Su calculadora está alineada al patrón real de uso que propusieron o solo al despliegue técnico?
- ¿Qué mejorarían si esto fuera productivo?
- Si usan App Service: ¿cómo configuraron el despliegue desde GitHub?
- ¿Qué ventaja tiene desplegar desde repositorio en vez de hacerlo manualmente?

> Página 5

## 15. Tabla de evaluación

| Criterio | Descripción | Porcentaje |
| --- | --- | --- |
| Diseño de arquitectura | Claridad del diseño Hub and Spoke, segmentación y justificación técnica. | 20% |
| Implementación técnica | Despliegue correcto de Hub, Spoke, Bastion, VPN Gateway, app, base de datos y Storage. | 30% |
| Seguridad y conectividad privada | Uso correcto de acceso privado, VPN P2S, Bastion y ausencia de exposición pública. | 20% |
| Costos, tags y nomenclatura | Calidad de la calculadora, estimación, análisis de operación a 3 años, gobierno básico y consistencia de nombres. | 15% |
| Documentación y evidencias | Calidad del documento, diagrama y pruebas presentadas. | 10% |
| Presentación y defensa técnica | Capacidad para explicar y justificar la solución. | 5% |

Puntos extra: +5% si implementan correctamente automatización de encendido/apagado 8x5 en VMs. +5% si implementan correctamente despliegue automatizado desde GitHub hacia App Service.

## 16. Versión corta

- El Hub debe tener Azure Bastion, VPN Gateway y VPN Point-to-Site.
- El Spoke debe tener una aplicación web privada, una base de datos privada y un Storage privado consumidos por la aplicación.
- La app no debe ser pública.
- La base de datos y el Storage no deben ser públicos.
- No se permite IP pública en la VM de aplicación.
- Deben conectarse desde una laptop real por VPN P2S.
- Deben entregar calculadora pública de costo.
- Deben usar estrategia de tags y nomenclatura.
- Deben considerar que la intranet operará 3 años.
- Deben justificar si conviene pago por uso, reservación o una estrategia mixta.
- Deben demostrar funcionamiento.

Extras: si usan VM, puntos extra por automatizar encendido/apagado 8x5; si usan App Service, puntos extra por implementar despliegue automatizado desde GitHub.

Entregables: diagrama, documento técnico, evidencias, calculadora de Azure y demo en clase.

Página 6

Página 7
