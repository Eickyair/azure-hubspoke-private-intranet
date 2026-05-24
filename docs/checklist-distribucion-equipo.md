# Checklist de trabajo por persona

Este checklist sirve para repartir la practica entre varias personas sin perder de vista los entregables obligatorios.

## Reparto sugerido del equipo

- Persona 1: coordinacion general, documento tecnico y cierre de entrega.
- Persona 2: Hub, peering, Bastion y VPN P2S.
- Persona 3: aplicaciones privadas de Spoke 1.
- Persona 4: base de datos y Storage privado de Spoke 2.
- Persona 5: analitica de Spoke 3, dashboard y ETL.
- Persona 6: costos, evidencias, validacion final y demo.

Si el equipo tiene menos personas, se pueden combinar asi:

- 4 personas: unir Persona 1 con Persona 6, y Persona 4 con Persona 5.
- 5 personas: unir Persona 1 con Persona 6.

## Persona 1 - Coordinacion y documento tecnico

- [ ] Confirmar el alcance final del laboratorio y los entregables obligatorios.
- [ ] Revisar que la arquitectura elegida coincida con el enunciado y con lo desplegado.
- [ ] Consolidar direccionamiento IP, nombres de recursos y decisiones tecnicas.
- [ ] Redactar el documento tecnico final de 3 a 6 paginas.
- [ ] Integrar en el documento: objetivo, arquitectura, red, IPs, servicios y flujo de acceso.
- [ ] Integrar en el documento: explicacion de por que la app no es publica.
- [ ] Integrar en el documento: explicacion de por que la base de datos no es publica.
- [ ] Integrar en el documento: explicacion de por que el Storage no es publico.
- [ ] Integrar en el documento: estrategia de nomenclatura y estrategia de tags.
- [ ] Integrar en el documento: resumen de costos y analisis a 3 anos.
- [ ] Integrar en el documento: problemas encontrados y como se resolvieron.
- [ ] Validar que el documento final use las evidencias reales del entorno.

Entregable esperado:

- Documento tecnico listo para entregar.

## Persona 2 - Hub, conectividad y acceso seguro

- [ ] Revisar el modulo Hub y confirmar que existan Hub VNet, AzureBastionSubnet y GatewaySubnet.
- [ ] Verificar que el peering Hub-Spoke este creado y funcional.
- [ ] Confirmar que Azure Bastion quede operativo para administracion segura.
- [ ] Habilitar VPN P2S en la configuracion final del despliegue.
- [ ] Cargar el certificado raiz publico correcto para la VPN.
- [ ] Desplegar o actualizar el VPN Gateway del Hub.
- [ ] Probar la conexion VPN desde una laptop real del equipo.
- [ ] Validar acceso desde la laptop a recursos privados del entorno.
- [ ] Capturar evidencia de cliente VPN conectado y acceso a recursos internos.
- [ ] Confirmar que no haya RDP ni SSH abiertos a internet.
- [ ] Confirmar que las VMs de aplicacion no tengan IP publica si aplica.

Entregable esperado:

- Evidencia de VPN P2S funcional y acceso privado real.

## Persona 3 - Aplicacion privada de Spoke 1

- [ ] Revisar que las webapps y APIs privadas esten desplegadas en Spoke 1.
- [ ] Verificar que la app no sea publica y que el acceso quede restringido a red privada.
- [ ] Validar integracion entre frontend y APIs privadas.
- [ ] Verificar configuracion de Private Endpoints y DNS privado para App Services.
- [ ] Probar que la intranet y el portal admin funcionen usando URLs internas.
- [ ] Validar que la app consulte informacion real desde la base de datos.
- [ ] Validar que la app consuma contenido real desde Blob Storage.
- [ ] Preparar capturas o evidencia funcional de la app en red privada.
- [ ] Documentar problemas de aplicacion, DNS o conectividad y su solucion.

Entregable esperado:

- Evidencia funcional de la aplicacion privada consumiendo datos y Storage.

## Persona 4 - Base de datos y Storage privado de Spoke 2

- [ ] Verificar que MySQL Flexible Server este desplegado de forma privada o restringida.
- [ ] Verificar que Blob Storage este privado o restringido por red.
- [ ] Confirmar Private Endpoints y Private DNS para MySQL y Blob.
- [ ] Ejecutar la carga de esquema y datos demo postdeploy.
- [ ] Validar que las bases contengan datos esperados.
- [ ] Ejecutar la carga de imagenes o documentos al Blob privado.
- [ ] Probar que la aplicacion pueda leer datos de MySQL.
- [ ] Probar que la aplicacion pueda leer imagenes o documentos desde Storage.
- [ ] Confirmar que ni base de datos ni Storage queden expuestos publicamente.
- [ ] Preparar evidencia de recursos creados y pruebas de conectividad privada.

Entregable esperado:

- Evidencia de MySQL y Blob privados funcionando con la aplicacion.

## Persona 5 - Spoke 3, analitica y operacion interna

- [ ] Verificar despliegue de la VM ETL y del dashboard privado.
- [ ] Confirmar que ambas VMs solo sean administrables por red privada.
- [ ] Validar conectividad del ETL hacia las bases operativas y la base analitica.
- [ ] Ejecutar el flujo ETL y revisar que cargue datos en la base analitica.
- [ ] Validar que el dashboard consulte la base analitica correctamente.
- [ ] Probar acceso interno al dashboard desde la red privada.
- [ ] Preparar capturas de funcionamiento del dashboard y del proceso ETL.
- [ ] Documentar incidencias de conectividad, dependencias o datos.

Entregable esperado:

- Evidencia de capa analitica funcionando dentro de la red privada.

## Persona 6 - Costos, evidencias y demo final

- [ ] Construir la Azure Pricing Calculator con los recursos realmente usados.
- [ ] Incluir en la calculadora: VMs, discos, App Service, MySQL, VPN Gateway, Bastion, IPs y Storage.
- [ ] Registrar supuestos de uso, region y SKUs elegidos.
- [ ] Calcular costo mensual estimado.
- [ ] Elaborar el analisis de costo a 3 anos.
- [ ] Justificar si conviene pago por uso, reservacion o estrategia mixta.
- [ ] Identificar los componentes mas costosos.
- [ ] Guardar enlace publico o evidencia exportada de la calculadora.
- [ ] Recolectar todas las capturas del entorno y ordenarlas por seccion.
- [ ] Armar el orden de la demo de 10 a 15 minutos.
- [ ] Ensayar la defensa tecnica con preguntas guia.
- [ ] Verificar que no falte ninguna evidencia antes de entregar.

Entregable esperado:

- Calculadora publica, paquete de evidencias y guion de demo.

## Checklist transversal de cierre

- [ ] Existe arquitectura Hub and Spoke desplegada.
- [ ] Existe Hub con Bastion y VPN Gateway.
- [ ] Existe conectividad P2S real desde laptop.
- [ ] La aplicacion esta en red privada y no publica.
- [ ] La base de datos no es publica.
- [ ] El Storage no es publico.
- [ ] La aplicacion consume base de datos y Blob Storage.
- [ ] Existe peering entre Hub y Spokes.
- [ ] Existe estrategia de nomenclatura consistente.
- [ ] Todos los recursos tienen tags obligatorios.
- [ ] Existe calculadora publica o evidencia equivalente.
- [ ] Existe analisis de costos a 3 anos.
- [ ] Existe documento tecnico final.
- [ ] Existen capturas claras y pruebas funcionales.
- [ ] Existe demo preparada para exposicion.

## Dependencias importantes

- La Persona 2 debe cerrar VPN y conectividad antes de la validacion final.
- La Persona 4 debe cargar datos y Blob antes de las pruebas funcionales de la Persona 3.
- La Persona 5 depende de la base de datos operativa para ETL y dashboard.
- La Persona 6 depende de evidencias reales del resto del equipo para cerrar costos y demo.
- La Persona 1 consolida el material final cuando las demas personas entreguen pruebas y hallazgos.

## Recomendacion de seguimiento

- Hacer una revision corta diaria de 10 minutos.
- Marcar bloqueos tecnicos en cuanto aparezcan.
- No dejar para el final la VPN P2S ni la calculadora de costos.
- Guardar todas las capturas con nombre claro y fecha.
- Validar el entorno completo con una demo corrida de punta a punta antes de entregar.
