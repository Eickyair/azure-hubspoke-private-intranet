# Politica de etiquetado

## Objetivo

Esta politica define las etiquetas obligatorias que deben aplicarse a todos los recursos desplegados por Terraform antes de cualquier `plan` o `apply`.

## Alcance

Aplica a todos los recursos de la solucion Hub-Spoke, incluyendo red, App Services, bases de datos, Storage Account, observabilidad y componentes de seguridad.

## Etiquetas obligatorias

| Tag | Descripcion | Valor por defecto |
| --- | --- | --- |
| `Project` | Nombre del proyecto | `PrivateIntranet` |
| `Environment` | Ambiente del despliegue | `lab` |
| `Owner` | Responsable operativo | `EquipoCloud` |
| `ManagedBy` | Herramienta de gestion | `Terraform` |
| `CostCenter` | Centro de costo academico | `CloudClass` |
| `Workload` | Tipo de carga | `PrivateIntranet` |
| `Criticality` | Criticidad del servicio | `Medium` |
| `Region` | Region objetivo | `mexicocentral` |
| `Architecture` | Patron arquitectonico | `HubSpoke` |
| `ResourceScope` | Alcance de agrupacion | `SharedResourceGroup` |

## Regla operativa

- Ningun recurso se despliega sin el bloque `locals.default_tags` del ambiente.
- Las etiquetas por defecto pueden ampliarse con la variable `tags`, pero no deben eliminar las obligatorias.
- Cualquier cambio de taxonomia debe reflejarse primero en Terraform y despues en esta politica.

## Implementacion actual

En el estado actual del repositorio no se incluye aun la carpeta de Terraform. Cuando la infraestructura se incorpore al workspace, las etiquetas deben consolidarse en el punto de entrada del ambiente y propagarse a todos los modulos antes de crear recursos.

## Prechequeo antes del despliegue

1. Confirmar `resource_group_name`.
2. Confirmar `location = "mexicocentral"`.
3. Confirmar que `locals.default_tags` incluya todas las etiquetas obligatorias.
4. Ejecutar `terraform plan` y revisar que todos los recursos muestren el bloque `tags`.
