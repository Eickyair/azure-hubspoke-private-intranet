#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="$TERRAFORM_DIR/main.tfvars"
PLAN_FILE="tfplan-destroy"
AUTO_APPROVE=false
SKIP_INIT=false
SKIP_VALIDATE=false
WAIT_FOR_DELETE=false

RESOURCE_GROUP=""
PLAN_EXIT_CODE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Elimina de forma idempotente la infraestructura del laboratorio con Terraform.

Options:
  --tfvars <path>          Ruta al archivo tfvars. Default: terraform/main.tfvars
  --plan-file <name>       Nombre o ruta del plan file. Default: tfplan-destroy
  --auto-approve           Aplica el destroy sin confirmacion interactiva
  --wait                   Espera hasta que Azure confirme que el Resource Group fue eliminado
  --skip-init              Omite terraform init
  --skip-validate          Omite terraform validate
  -h, --help               Muestra esta ayuda

Examples:
  ./scripts/destroy-infra.sh
  ./scripts/destroy-infra.sh --auto-approve --wait
  ./scripts/destroy-infra.sh --tfvars terraform/main.tfvars --plan-file tfplan-lab-destroy
EOF
}

log() {
  printf '[destroy-infra] %s\n' "$*"
}

warn() {
  printf '[destroy-infra] WARN: %s\n' "$*" >&2
}

error() {
  printf '[destroy-infra] ERROR: %s\n' "$*" >&2
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

display_plan_path() {
  if [[ "$PLAN_FILE" = /* ]]; then
    printf '%s\n' "$PLAN_FILE"
  else
    printf '%s/%s\n' "$TERRAFORM_DIR" "$PLAN_FILE"
  fi
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

load_resource_group() {
  RESOURCE_GROUP="$(read_tfvars_string resource_group_name)"
  if [[ -z "$RESOURCE_GROUP" ]]; then
    error "Could not read resource_group_name from $TFVARS_FILE"
    exit 1
  fi
}

require_prerequisites() {
  require_command az
  require_command terraform
  require_command awk

  if [[ ! -f "$TFVARS_FILE" ]]; then
    error "Terraform tfvars file not found: $TFVARS_FILE"
    exit 1
  fi

  if ! az account show >/dev/null 2>&1; then
    error "Azure CLI is not authenticated. Run 'az login' first."
    exit 1
  fi
}

get_resource_group_state() {
  az group show --name "$RESOURCE_GROUP" --query 'properties.provisioningState' --output tsv 2>/dev/null || true
}

wait_resource_group_deleted() {
  log "Waiting for Azure Resource Group deletion: $RESOURCE_GROUP"
  az group wait --deleted --name "$RESOURCE_GROUP"
}

check_resource_group_state() {
  local provisioning_state
  provisioning_state="$(get_resource_group_state)"

  if [[ -z "$provisioning_state" ]]; then
    log "Resource Group '$RESOURCE_GROUP' does not exist in Azure. Terraform destroy will still run to reconcile local state if needed."
    return 0
  fi

  if [[ "$provisioning_state" == "Deleting" ]]; then
    log "Resource Group '$RESOURCE_GROUP' is already deleting. Nothing new to start."
    if [[ "$WAIT_FOR_DELETE" == true ]]; then
      wait_resource_group_deleted
    fi
    exit 0
  fi

  log "Resource Group '$RESOURCE_GROUP' state: $provisioning_state"
}

run_terraform_init() {
  terraform -chdir="$TERRAFORM_DIR" init
}

run_terraform_validate() {
  terraform -chdir="$TERRAFORM_DIR" validate
}

run_destroy_plan() {
  rm -f "$(display_plan_path)"

  set +e
  terraform -chdir="$TERRAFORM_DIR" plan \
    -destroy \
    -var-file="$TFVARS_FILE" \
    -input=false \
    -lock=false \
    -detailed-exitcode \
    -out="$PLAN_FILE"
  PLAN_EXIT_CODE=$?
  set -e

  case "$PLAN_EXIT_CODE" in
    0)
      log "No Terraform-managed resources need deletion."
      ;;
    2)
      log "Destroy plan created: $(display_plan_path)"
      ;;
    *)
      error "terraform plan -destroy failed with exit code $PLAN_EXIT_CODE"
      exit "$PLAN_EXIT_CODE"
      ;;
  esac
}

run_destroy_apply() {
  terraform -chdir="$TERRAFORM_DIR" apply -input=false -lock=false "$PLAN_FILE"
}

print_summary() {
  printf '\nDestroy summary\n'
  printf '%s\n' '---------------'
  printf 'TFVARS: %s\n' "$TFVARS_FILE"
  printf 'Plan:   %s\n' "$(display_plan_path)"
  printf 'RG:     %s\n' "$RESOURCE_GROUP"

  if [[ "$PLAN_EXIT_CODE" == "0" ]]; then
    printf '\nNo hay cambios pendientes de destruccion. Puedes ejecutar el script otra vez sin efectos secundarios.\n'
    return 0
  fi

  if [[ "$AUTO_APPROVE" == false ]]; then
    printf '\nPlan de destruccion creado. Para eliminar la infraestructura:\n'
    printf 'terraform -chdir=terraform apply -input=false -lock=false %q\n' "$PLAN_FILE"
    printf '\nO ejecuta el script completo:\n'
    printf './scripts/destroy-infra.sh --auto-approve --wait\n'
  else
    printf '\nDestroy aplicado. Puedes reejecutar el script para verificar idempotencia.\n'
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tfvars)
      [[ $# -ge 2 ]] || { error "Missing value for --tfvars"; exit 2; }
      TFVARS_FILE="$(resolve_path "$2")"
      shift 2
      ;;
    --plan-file)
      [[ $# -ge 2 ]] || { error "Missing value for --plan-file"; exit 2; }
      PLAN_FILE="$2"
      shift 2
      ;;
    --auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    --wait)
      WAIT_FOR_DELETE=true
      shift
      ;;
    --skip-init)
      SKIP_INIT=true
      shift
      ;;
    --skip-validate)
      SKIP_VALIDATE=true
      shift
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
load_resource_group
check_resource_group_state

if [[ "$SKIP_INIT" == false ]]; then
  log "Running terraform init"
  run_terraform_init
else
  warn "Skipping terraform init"
fi

if [[ "$SKIP_VALIDATE" == false ]]; then
  log "Running terraform validate"
  run_terraform_validate
else
  warn "Skipping terraform validate"
fi

log "Creating terraform destroy plan"
run_destroy_plan

if [[ "$PLAN_EXIT_CODE" == "0" ]]; then
  print_summary
  exit 0
fi

if [[ "$AUTO_APPROVE" == false ]]; then
  print_summary
  exit 0
fi

log "Applying terraform destroy plan"
run_destroy_apply

if [[ "$WAIT_FOR_DELETE" == true ]]; then
  wait_resource_group_deleted
fi

print_summary