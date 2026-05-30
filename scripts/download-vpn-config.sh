#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="${TFVARS_FILE:-$TERRAFORM_DIR/main.tfvars}"
CERTS_DIR="${CERTS_DIR:-$ROOT_DIR/vpn-certs}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/vpn-config}"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
success() { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
warn()    { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
error()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

read_tfvars() {
  awk -F '"' -v key="$1" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$TFVARS_FILE"
}

# ── Validaciones previas ──────────────────────────────────────────────────────
[[ -f "$TFVARS_FILE" ]]       || error "No se encontró el archivo tfvars: $TFVARS_FILE"
command -v az     &>/dev/null || error "Azure CLI (az) no está instalado."
command -v curl   &>/dev/null || error "curl no está instalado."
command -v python3 &>/dev/null || error "python3 no está instalado."
az account show   &>/dev/null || error "No hay sesión activa en Azure CLI. Ejecuta: az login"

# ── Verificar certificados del cliente ───────────────────────────────────────
CLIENT_CERT="$CERTS_DIR/client.crt"
CLIENT_KEY="$CERTS_DIR/client.key"

if [[ ! -f "$CLIENT_CERT" || ! -f "$CLIENT_KEY" ]]; then
  error "No se encontraron los certificados del cliente en $CERTS_DIR.
  Ejecuta primero: ./scripts/generate-vpn-certs.sh"
fi

# ── Leer variables del proyecto ───────────────────────────────────────────────
RESOURCE_GROUP="$(read_tfvars resource_group_name)"
PROJECT_SLUG="$(read_tfvars project_slug)"
ENVIRONMENT="$(read_tfvars environment)"
UNIQUE_SUFFIX="$(read_tfvars unique_suffix)"

[[ -n "$RESOURCE_GROUP" ]] || error "No se pudo leer 'resource_group_name' de $TFVARS_FILE"
[[ -n "$PROJECT_SLUG" ]]   || error "No se pudo leer 'project_slug' de $TFVARS_FILE"
[[ -n "$ENVIRONMENT" ]]    || error "No se pudo leer 'environment' de $TFVARS_FILE"
[[ -n "$UNIQUE_SUFFIX" ]]  || error "No se pudo leer 'unique_suffix' de $TFVARS_FILE"

NAME_PREFIX="${PROJECT_SLUG}-${ENVIRONMENT}-${UNIQUE_SUFFIX}"
GW_NAME="vpngw-${NAME_PREFIX}-hub"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

info "Resource Group : $RESOURCE_GROUP"
info "VPN Gateway    : $GW_NAME"

# ── Verificar que el gateway exista y esté listo ──────────────────────────────
info "Verificando estado del VPN Gateway..."
GW_STATE="$(az network vnet-gateway show \
  --name "$GW_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'provisioningState' \
  --output tsv 2>/dev/null)" \
  || error "No se encontró el gateway '$GW_NAME' en el RG '$RESOURCE_GROUP'."

[[ "$GW_STATE" == "Succeeded" ]] \
  || error "El gateway no está listo (estado: $GW_STATE)."
success "Gateway listo."

# ── Generar y descargar el paquete VPN ───────────────────────────────────────
info "Generando paquete de configuración VPN P2S (puede tardar 1-2 min)..."
DOWNLOAD_URL="$(az network vnet-gateway vpn-client generate \
  --name "$GW_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --processor-architecture Amd64 \
  --output tsv 2>/dev/null)"

DOWNLOAD_URL="${DOWNLOAD_URL//\"/}"
[[ -n "$DOWNLOAD_URL" ]] || error "No se obtuvo URL de descarga. Verifica que el gateway tenga configuración P2S activa."

ZIP_FILE="$WORK_DIR/vpnclient.zip"
info "Descargando paquete..."
curl -fsSL "$DOWNLOAD_URL" -o "$ZIP_FILE"
success "Paquete descargado."

# ── Extraer e inyectar certificado y clave del cliente ───────────────────────
info "Extrayendo perfil OpenVPN e inyectando certificados..."

OVPN_TEMPLATE="$WORK_DIR/vpnconfig.ovpn"

python3 - "$ZIP_FILE" "$OVPN_TEMPLATE" "$CLIENT_CERT" "$CLIENT_KEY" <<'PYEOF'
import sys, pathlib, zipfile

zip_path  = pathlib.Path(sys.argv[1])
ovpn_out  = pathlib.Path(sys.argv[2])
cert      = pathlib.Path(sys.argv[3]).read_text().strip()
key       = pathlib.Path(sys.argv[4]).read_text().strip()

# Extrae vpnconfig.ovpn manejando rutas con backslash de Windows sin warnings
with zipfile.ZipFile(zip_path) as zf:
    for member in zf.namelist():
        if member.replace('\\', '/').lower().endswith('openvpn/vpnconfig.ovpn'):
            content = zf.read(member).decode('utf-8')
            break
    else:
        raise SystemExit("ERROR: vpnconfig.ovpn no encontrado en el zip")

content = content.replace('$CLIENTCERTIFICATE', cert)
content = content.replace('$PRIVATEKEY', key)
ovpn_out.write_text(content)
PYEOF

[[ -f "$OVPN_TEMPLATE" ]] || error "No se pudo extraer vpnconfig.ovpn del paquete descargado."

# ── Copiar el perfil final al directorio de salida ────────────────────────────
mkdir -p "$OUTPUT_DIR"
FINAL_OVPN="$OUTPUT_DIR/${NAME_PREFIX}-${TIMESTAMP}.ovpn"
cp "$OVPN_TEMPLATE" "$FINAL_OVPN"

success "Perfil OpenVPN listo."

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Perfil listo para importar:"
echo ""
echo "    $FINAL_OVPN"
echo ""
echo "  Cómo importarlo:"
echo "    • OpenVPN Connect / OpenVPN GUI:"
echo "        Archivo → Importar perfil → selecciona el .ovpn"
echo "    • Linux (nmcli):"
echo "        nmcli connection import type openvpn file \"$FINAL_OVPN\""
echo "    • Linux (openvpn directo):"
echo "        sudo openvpn --config \"$FINAL_OVPN\""
echo "════════════════════════════════════════════════════════════"
