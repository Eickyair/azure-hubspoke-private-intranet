#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="$TERRAFORM_DIR/main.tfvars"
BACKEND_CONFIG_FILE="$TERRAFORM_DIR/backend.hcl"
BACKEND_RESOURCE_GROUP=""
BACKEND_LOCATION=""
BACKEND_STORAGE_ACCOUNT=""
BACKEND_CONTAINER="tfstate"
BACKEND_KEY="azure-hubspoke-private-intranet.tfstate"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Crea la cuenta de Storage para el backend remoto de Terraform y escribe terraform/backend.hcl.

Options:
  --tfvars <path>             Ruta al archivo tfvars. Default: terraform/main.tfvars
  --resource-group <name>     Resource Group del backend. Default: rg-<project_slug>-<environment>-tfstate
  --location <azure-region>   Region del backend. Default: toma location de main.tfvars
  --storage-account <name>    Nombre de la Storage Account. Default: derivado de proyecto y suscripcion
  --container <name>          Contenedor Blob para el state. Default: tfstate
  --key <path>                Blob key del state. Default: azure-hubspoke-private-intranet.tfstate
  --backend-config <path>     Ruta de salida del backend.hcl. Default: terraform/backend.hcl
  -h, --help                  Muestra esta ayuda

Examples:
  ./scripts/bootstrap-tfstate-backend.sh
  ./scripts/bootstrap-tfstate-backend.sh --container tfstate --key lab/shared.tfstate
  ./scripts/bootstrap-tfstate-backend.sh --backend-config terraform/backend.hcl
EOF
}

log() {
  printf '[bootstrap-tfstate] %s\n' "$*"
}

error() {
  printf '[bootstrap-tfstate] ERROR: %s\n' "$*" >&2
}

resolve_path() {
  local input_path="$1"

  if [[ "$input_path" = /* ]]; then
    printf '%s\n' "$input_path"
    return 0
  fi

  if [[ "$input_path" == terraform/* ]]; then
    printf '%s/%s\n' "$ROOT_DIR" "$input_path"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$input_path"
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    error "Missing required command: $command_name"
    exit 1
  fi
}

read_tfvars_string() {
  local key="$1"
  awk -F '"' -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$TFVARS_FILE"
}

sanitize_storage_account_name() {
  local raw_name="$1"
  printf '%s' "$raw_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | cut -c1-24
}

load_defaults() {
  local project_slug
  local environment
  local location
  local subscription_id
  local subscription_hash

  project_slug="$(read_tfvars_string project_slug)"
  environment="$(read_tfvars_string environment)"
  location="$(read_tfvars_string location)"

  if [[ -z "$project_slug" || -z "$environment" || -z "$location" ]]; then
    error "Could not read project_slug, environment or location from $TFVARS_FILE"
    exit 1
  fi

  subscription_id="$(az account show --query id --output tsv)"
  subscription_hash="$(printf '%s' "$subscription_id" | sha256sum | awk '{print substr($1,1,6)}')"

  if [[ -z "$BACKEND_RESOURCE_GROUP" ]]; then
    BACKEND_RESOURCE_GROUP="rg-${project_slug}-${environment}-tfstate"
  fi

  if [[ -z "$BACKEND_LOCATION" ]]; then
    BACKEND_LOCATION="$location"
  fi

  if [[ -z "$BACKEND_STORAGE_ACCOUNT" ]]; then
    BACKEND_STORAGE_ACCOUNT="$(sanitize_storage_account_name "st${project_slug}${environment}tf${subscription_hash}")"
  fi
}

require_prerequisites() {
  require_command az
  require_command awk
  require_command sha256sum

  if [[ ! -f "$TFVARS_FILE" ]]; then
    error "Terraform tfvars file not found: $TFVARS_FILE"
    exit 1
  fi

  if ! az account show >/dev/null 2>&1; then
    error "Azure CLI is not authenticated. Run 'az login' first."
    exit 1
  fi
}

create_backend_resources() {
  local account_key

  log "Creating or reusing backend resource group: $BACKEND_RESOURCE_GROUP"
  az group create \
    --name "$BACKEND_RESOURCE_GROUP" \
    --location "$BACKEND_LOCATION" \
    --output none

  if ! az storage account show --resource-group "$BACKEND_RESOURCE_GROUP" --name "$BACKEND_STORAGE_ACCOUNT" >/dev/null 2>&1; then
    log "Creating backend storage account: $BACKEND_STORAGE_ACCOUNT"
    az storage account create \
      --name "$BACKEND_STORAGE_ACCOUNT" \
      --resource-group "$BACKEND_RESOURCE_GROUP" \
      --location "$BACKEND_LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --https-only true \
      --min-tls-version TLS1_2 \
      --allow-blob-public-access false \
      --output none
  else
    log "Backend storage account already exists: $BACKEND_STORAGE_ACCOUNT"
  fi

  account_key="$(az storage account keys list \
    --resource-group "$BACKEND_RESOURCE_GROUP" \
    --account-name "$BACKEND_STORAGE_ACCOUNT" \
    --query '[0].value' \
    --output tsv)"

  log "Creating or reusing backend container: $BACKEND_CONTAINER"
  az storage container create \
    --name "$BACKEND_CONTAINER" \
    --account-name "$BACKEND_STORAGE_ACCOUNT" \
    --account-key "$account_key" \
    --output none >/dev/null
}

write_backend_config() {
  mkdir -p "$(dirname "$BACKEND_CONFIG_FILE")"

  cat >"$BACKEND_CONFIG_FILE" <<EOF
resource_group_name  = "$BACKEND_RESOURCE_GROUP"
storage_account_name = "$BACKEND_STORAGE_ACCOUNT"
container_name       = "$BACKEND_CONTAINER"
key                  = "$BACKEND_KEY"
EOF

  chmod 600 "$BACKEND_CONFIG_FILE"
}

print_next_steps() {
  printf '\nBackend remoto listo\n'
  printf '%s\n' '-------------------'
  printf 'Resource Group:  %s\n' "$BACKEND_RESOURCE_GROUP"
  printf 'Storage Account: %s\n' "$BACKEND_STORAGE_ACCOUNT"
  printf 'Container:       %s\n' "$BACKEND_CONTAINER"
  printf 'State key:       %s\n' "$BACKEND_KEY"
  printf 'Backend config:  %s\n' "$BACKEND_CONFIG_FILE"
  printf '\nSi ya tienes state local, migralo con:\n'
  printf 'terraform -chdir=terraform init -migrate-state -backend-config=%q\n' "$BACKEND_CONFIG_FILE"
  printf '\nPara despliegues en equipo usa:\n'
  printf './scripts/deploy-full.sh --backend-config %q\n' "$BACKEND_CONFIG_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tfvars)
      [[ $# -ge 2 ]] || { error "Missing value for --tfvars"; exit 2; }
      TFVARS_FILE="$(resolve_path "$2")"
      shift 2
      ;;
    --resource-group)
      [[ $# -ge 2 ]] || { error "Missing value for --resource-group"; exit 2; }
      BACKEND_RESOURCE_GROUP="$2"
      shift 2
      ;;
    --location)
      [[ $# -ge 2 ]] || { error "Missing value for --location"; exit 2; }
      BACKEND_LOCATION="$2"
      shift 2
      ;;
    --storage-account)
      [[ $# -ge 2 ]] || { error "Missing value for --storage-account"; exit 2; }
      BACKEND_STORAGE_ACCOUNT="$(sanitize_storage_account_name "$2")"
      shift 2
      ;;
    --container)
      [[ $# -ge 2 ]] || { error "Missing value for --container"; exit 2; }
      BACKEND_CONTAINER="$2"
      shift 2
      ;;
    --key)
      [[ $# -ge 2 ]] || { error "Missing value for --key"; exit 2; }
      BACKEND_KEY="$2"
      shift 2
      ;;
    --backend-config)
      [[ $# -ge 2 ]] || { error "Missing value for --backend-config"; exit 2; }
      BACKEND_CONFIG_FILE="$(resolve_path "$2")"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

require_prerequisites
load_defaults
create_backend_resources
write_backend_config
print_next_steps