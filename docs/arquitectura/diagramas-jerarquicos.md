# Diagramas jerarquicos de arquitectura

La arquitectura se separa en una vista general y una vista dedicada por modulo para mejorar legibilidad y defensa tecnica.

## Convenciones comunes

- Hub VNet: `10.10.0.0/16`
- Spoke 1 - Aplicaciones: `10.20.0.0/16`
- Spoke 2 - Datos y documentos: `10.30.0.0/16`
- Spoke 3 - Analitica: `10.40.0.0/16`
- Pool VPN Point-to-Site: `172.16.10.0/24`
- Dominios internos: `intranet.northwind.lab`, `admin.northwind.lab`, `api.northwind.lab`, `kpi.northwind.lab`
- Zonas privadas usadas en el Hub: `privatelink.azurewebsites.net`, `privatelink.mysql.database.azure.com`, `privatelink.blob.core.windows.net`, `privatelink.vaultcore.azure.net`

## Vistas disponibles

- [Diagrama 0 - Vista General](./arquitectura-python-mysql.mmd)
- [Diagrama 1 - Hub VNet](./hub-vnet-detalle.mmd)
- [Diagrama 2 - Spoke 1 / Aplicaciones](./spoke1-aplicaciones-detalle.mmd)
- [Diagrama 3 - Spoke 2 / Datos y documentos](./spoke2-datos-detalle.mmd)
- [Diagrama 4 - Spoke 3 / Analitica](./spoke3-analitica-detalle.mmd)

## Criterio de lectura

- Cada diagrama usa la misma paleta: verde para Hub, azul para aplicaciones, amarillo para datos, morado para analitica y rojo solo para servicios externos reales o de terceros.
- Los contenedores de red representan `VNets` y `subnets`.
- Las flechas solidas representan trafico principal del modulo.
- Las flechas punteadas representan servicios compartidos, control o gestion.
- Cuando un modulo depende de otro, se muestra como una caja externa prefijada con el nombre del spoke origen y conservando el color del modulo al que pertenece.
