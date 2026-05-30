#!/usr/bin/env bash
# download-diag-logs.sh
# Descarga el ultimo log de diagnostico desde C:\diag\ en el Jumpbox de Azure
# al directorio local diag-logs/
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="${TFVARS_FILE:-$TERRAFORM_DIR/main.tfvars}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/diag-logs}"
MAX_LINES="${MAX_LINES:-5000}"

# ── helpers ───────────────────────────────────────────────────────────────────
log()   { printf '[download-diag] %s\n' "$*"; }
error() { printf '[download-diag] ERROR: %s\n' "$*" >&2; }

require_command() { command -v "$1" >/dev/null 2>&1 || { error "Missing: $1"; exit 1; }; }

read_tfvars_string() {
  awk -F '"' -v key="$1" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$TFVARS_FILE"
}

run_ps_on_jumpbox() {
  local rg="$1" vm="$2" script="$3"
  az vm run-command invoke \
    --resource-group "$rg" \
    --name          "$vm" \
    --command-id    RunPowerShellScript \
    --scripts       "$script" \
    --query         'value[0].message' \
    --output        tsv 2>/dev/null
}

# ── prerequisites ─────────────────────────────────────────────────────────────
require_command az
require_command jq
require_command terraform

if ! az account show >/dev/null 2>&1; then
  error "Azure CLI no autenticado. Ejecuta: az login"
  exit 1
fi

if [[ ! -f "$TFVARS_FILE" ]]; then
  error "tfvars no encontrado: $TFVARS_FILE"
  exit 1
fi

# ── load terraform outputs ────────────────────────────────────────────────────
log "Leyendo outputs de Terraform..."
tf_output="$(terraform -chdir="$TERRAFORM_DIR" output -json 2>/dev/null)" || {
  error "No se pudo leer terraform output. Asegurate de que el workspace este inicializado."
  exit 1
}

RESOURCE_GROUP="$(jq -er '.resource_group_name.value' <<<"$tf_output")"
JUMPBOX_VM="$(jq -er '.jumpbox_access.value.vm_name'  <<<"$tf_output")"

log "Resource Group : $RESOURCE_GROUP"
log "Jumpbox VM     : $JUMPBOX_VM"

mkdir -p "$OUT_DIR"

# ── discover latest log files ─────────────────────────────────────────────────
log "Buscando archivos de diagnostico en C:\\diag\\..."

DISCOVER_PS='
$files = Get-ChildItem "C:\diag\" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 4
foreach ($f in $files) {
    Write-Output "$($f.LastWriteTime.ToString("o"))|$($f.FullName)|$($f.Length)"
}
'
file_list="$(run_ps_on_jumpbox "$RESOURCE_GROUP" "$JUMPBOX_VM" "$DISCOVER_PS")"

if [[ -z "$file_list" ]]; then
  error "No se encontraron archivos en C:\\diag\\ (quizas el script de diagnostico no se ha ejecutado aun)"
  exit 1
fi

log "Archivos encontrados:"
while IFS='|' read -r ts path size; do
  printf '  %s  %-12s  %s\n' "$ts" "${size:-?} bytes" "$path"
done <<<"$file_list"

# ── download each file ────────────────────────────────────────────────────────
while IFS='|' read -r _ts remote_path _size; do
  [[ -z "$remote_path" ]] && continue
  local_name="$(basename "$remote_path")"
  local_path="$OUT_DIR/$local_name"

  log "Descargando $remote_path -> $local_path ..."

  ext="${local_name##*.}"
  if [[ "$ext" == "json" ]]; then
    # Para JSON, leer completo y guardar como JSON valido
    READ_PS="Get-Content -Raw -Path '${remote_path}'"
    content="$(run_ps_on_jumpbox "$RESOURCE_GROUP" "$JUMPBOX_VM" "$READ_PS")"
    printf '%s\n' "$content" > "$local_path"
  else
    # Para .txt, leer las ultimas MAX_LINES lineas (az run-command tiene limite de salida)
    READ_PS="
\$lines = Get-Content -Path '${remote_path}' -ErrorAction Stop
if (\$lines.Count -gt ${MAX_LINES}) {
    Write-Output \"[... ${MAX_LINES} ultimas lineas de \$(\$lines.Count) totales ...]\"
    \$lines | Select-Object -Last ${MAX_LINES} | ForEach-Object { Write-Output \$_ }
} else {
    \$lines | ForEach-Object { Write-Output \$_ }
}
"
    content="$(run_ps_on_jumpbox "$RESOURCE_GROUP" "$JUMPBOX_VM" "$READ_PS")"
    printf '%s\n' "$content" > "$local_path"
  fi

  log "  Guardado: $local_path  ($(wc -c < "$local_path") bytes)"
done <<<"$file_list"

# ── pretty-print JSON if available ───────────────────────────────────────────
json_file="$(find "$OUT_DIR" -name "*.json" -newer "$OUT_DIR" -maxdepth 1 2>/dev/null | sort | tail -1)"
if [[ -n "$json_file" ]] && command -v jq >/dev/null 2>&1; then
  log ""
  log "=== RESUMEN DEL ULTIMO JSON ==="
  jq -r '
    "Total checks : \(.total_checks // "?")",
    "PASS         : \(.passed // "?")",
    "FAIL         : \(.failed // "?")",
    "WARN         : \(.warned // "?")",
    "",
    "CHECKS FALLIDOS:",
    (.results // [] | map(select(.Status == "FAIL")) | .[] | "  [FAIL] \(.Name)\n         \(.Detail)")
  ' "$json_file" 2>/dev/null || true
fi

log ""
log "Logs guardados en: $OUT_DIR/"
log "Para ver el ultimo .txt: cat \$(ls -t $OUT_DIR/*.txt 2>/dev/null | head -1)"
