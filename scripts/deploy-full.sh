#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="$TERRAFORM_DIR/main.tfvars"
BACKEND_CONFIG_FILE="${TF_BACKEND_CONFIG_FILE:-$TERRAFORM_DIR/backend.hcl}"
PLAN_FILE="tfplan-full-deploy"
AUTO_APPROVE=false
SKIP_INIT=false
SKIP_BUILD=false
SKIP_DIAGNOSTICS=false
SKIP_DB=false
SKIP_IMAGES=false
DB_TASK="reset-demo"
DIAGNOSTICS_MAX_ATTEMPTS="${DIAGNOSTICS_MAX_ATTEMPTS:-5}"
DIAGNOSTICS_RETRY_DELAY="${DIAGNOSTICS_RETRY_DELAY:-30}"
TERRAFORM_APPLY_MAX_ATTEMPTS="${TERRAFORM_APPLY_MAX_ATTEMPTS:-3}"
TERRAFORM_APPLY_RETRY_DELAY="${TERRAFORM_APPLY_RETRY_DELAY:-60}"
TERRAFORM_LOCK_TIMEOUT="${TERRAFORM_LOCK_TIMEOUT:-5m}"
SUMMARY_MODE="full"

declare -A PHASE_STATUS=()
declare -A PHASE_DURATION=()
PHASE_ORDER=()

RESOURCE_GROUP=""
JUMPBOX_VM=""
SP2_APP_FQDN=""
SP2_ADMIN_FQDN=""
INTERNAL_URLS_JSON=""
DIAG_PASS=""
DIAG_WARN=""
DIAG_FAIL=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Deploy completo del laboratorio: build de prebuilts, Terraform, diagnosticos y postdeploy.

Options:
  --tfvars <path>          Ruta al archivo tfvars. Default: terraform/main.tfvars
  --backend-config <path>  Ruta al backend.hcl. Default: terraform/backend.hcl
  --plan-file <name>       Nombre o ruta del plan file. Default: tfplan-full-deploy
  --auto-approve           Ejecuta terraform apply y continua con diagnosticos/postdeploy
  --skip-init              Omite terraform init
  --skip-build             Omite build de paquetes prebuilt de Spoke 1
  --skip-diagnostics       Omite diagnosticos desde la jumpbox
  --skip-db                Omite postdeploy de bases de datos
  --skip-images            Omite carga de imagenes al Storage privado
  --db-task <task>         Task para postdeploy DB: schema|seed|verify|all|reset-demo
  -h, --help               Muestra esta ayuda

Examples:
  ./scripts/deploy-full.sh
  ./scripts/deploy-full.sh --backend-config terraform/backend.hcl
  ./scripts/deploy-full.sh --auto-approve --db-task reset-demo
  ./scripts/deploy-full.sh --tfvars terraform/main.tfvars --plan-file tfplan-lab
EOF
}

log() {
  printf '[deploy-full] %s\n' "$*"
}

warn() {
  printf '[deploy-full] WARN: %s\n' "$*" >&2
}

error() {
  printf '[deploy-full] ERROR: %s\n' "$*" >&2
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

check_resource_group_state() {
  local resource_group_name
  local provisioning_state

  resource_group_name="$(read_tfvars_string resource_group_name)"
  if [[ -z "$resource_group_name" ]]; then
    return 0
  fi

  set +e
  provisioning_state="$(az group show --name "$resource_group_name" --query 'properties.provisioningState' --output tsv 2>/dev/null)"
  local rc=$?
  set -e

  if [[ $rc -ne 0 || -z "$provisioning_state" ]]; then
    return 0
  fi

  if [[ "$provisioning_state" == "Deleting" ]]; then
    error "Resource group '$resource_group_name' is currently in Azure state 'Deleting'. Wait until deletion finishes before running deploy-full again."
    error "Useful command: az group wait --deleted --name $resource_group_name"
    exit 1
  fi
}

require_prerequisites() {
  local required_commands=(az terraform jq awk sed base64 zip sha256sum python3 install)
  local command_name

  for command_name in "${required_commands[@]}"; do
    require_command "$command_name"
  done

  if [[ ! -f "$TFVARS_FILE" ]]; then
    error "Terraform tfvars file not found: $TFVARS_FILE"
    exit 1
  fi

  if [[ "$SKIP_INIT" == false && ! -f "$BACKEND_CONFIG_FILE" ]]; then
    error "Terraform backend config not found: $BACKEND_CONFIG_FILE"
    error "Create it from terraform/backend.hcl.example or run ./scripts/bootstrap-tfstate-backend.sh first."
    exit 1
  fi

  if ! az account show >/dev/null 2>&1; then
    error "Azure CLI is not authenticated. Run 'az login' first."
    exit 1
  fi

  if [[ "$SKIP_DB" == true && "$SKIP_IMAGES" == false ]]; then
    warn "--skip-db was set; image upload assumes products already exist in MySQL."
  fi
}

record_phase() {
  local phase_name="$1"
  local status="$2"
  local duration="$3"

  PHASE_ORDER+=("$phase_name")
  PHASE_STATUS["$phase_name"]="$status"
  PHASE_DURATION["$phase_name"]="$duration"
}

run_phase() {
  local phase_name="$1"
  shift

  local start_ts=$SECONDS
  log "Starting phase: $phase_name"

  set +e
  "$@"
  local rc=$?
  set -e

  local duration=$((SECONDS - start_ts))
  if [[ $rc -eq 0 ]]; then
    record_phase "$phase_name" "ok" "$duration"
    log "Completed phase: $phase_name (${duration}s)"
  else
    record_phase "$phase_name" "failed" "$duration"
    error "Phase failed: $phase_name (${duration}s)"
    return $rc
  fi
}

run_build() {
  bash "$ROOT_DIR/scripts/build-spoke1-prebuilts.sh"
}

run_terraform_init() {
  terraform -chdir="$TERRAFORM_DIR" init -backend-config="$BACKEND_CONFIG_FILE"
}

run_terraform_validate() {
  terraform -chdir="$TERRAFORM_DIR" validate
}

run_terraform_plan() {
  terraform -chdir="$TERRAFORM_DIR" plan -var-file="$TFVARS_FILE" -input=false -lock-timeout="$TERRAFORM_LOCK_TIMEOUT" -out="$PLAN_FILE"
}

is_retryable_terraform_apply_error() {
  local output_file="$1"

  grep -q 'AnotherOperationInProgress' "$output_file"
}

run_terraform_apply() {
  local attempt=1
  local output_file
  local rc=0

  output_file="$(mktemp)"

  while (( attempt <= TERRAFORM_APPLY_MAX_ATTEMPTS )); do
    : >"$output_file"

    set +e
    terraform -chdir="$TERRAFORM_DIR" apply -input=false -lock-timeout="$TERRAFORM_LOCK_TIMEOUT" "$PLAN_FILE" 2>&1 | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    if [[ $rc -eq 0 ]]; then
      rm -f "$output_file"
      return 0
    fi

    if ! is_retryable_terraform_apply_error "$output_file"; then
      rm -f "$output_file"
      return $rc
    fi

    if (( attempt == TERRAFORM_APPLY_MAX_ATTEMPTS )); then
      error "Terraform apply exhausted ${TERRAFORM_APPLY_MAX_ATTEMPTS} attempts after Azure reported AnotherOperationInProgress."
      rm -f "$output_file"
      return $rc
    fi

    warn "Terraform apply hit Azure AnotherOperationInProgress on attempt ${attempt}/${TERRAFORM_APPLY_MAX_ATTEMPTS}; retrying in ${TERRAFORM_APPLY_RETRY_DELAY}s."
    sleep "$TERRAFORM_APPLY_RETRY_DELAY"
    attempt=$((attempt + 1))
  done

  rm -f "$output_file"
  return $rc
}

load_outputs() {
  local terraform_output
  terraform_output="$(terraform -chdir="$TERRAFORM_DIR" output -json)"

  RESOURCE_GROUP="$(jq -er '.resource_group_name.value' <<<"$terraform_output")"
  JUMPBOX_VM="$(jq -er '.jumpbox_access.value.vm_name' <<<"$terraform_output")"
  SP2_APP_FQDN="$(jq -er '.spoke2_mysql_fqdns.value.app' <<<"$terraform_output")"
  SP2_ADMIN_FQDN="$(jq -er '.spoke2_mysql_fqdns.value.admin' <<<"$terraform_output")"
  INTERNAL_URLS_JSON="$(jq -ec '.internal_urls.value' <<<"$terraform_output")"
}

parse_diag_count() {
  local label="$1"
  local diagnostics_output="$2"

  awk -v label="$label" '
    $1 == label {
      for (i = NF; i >= 1; i--) {
        if ($i ~ /^[0-9]+$/) {
          print $i
          exit
        }
      }
    }
  ' <<<"$diagnostics_output"
}

run_diagnostics() {
  local attempt=1
  local diagnostics_output=""
  local rc=0

  while (( attempt <= DIAGNOSTICS_MAX_ATTEMPTS )); do
    set +e
    diagnostics_output="$(az vm run-command invoke \
      --resource-group "$RESOURCE_GROUP" \
      --name "$JUMPBOX_VM" \
      --command-id RunPowerShellScript \
      --scripts "@$TERRAFORM_DIR/diagnostics.ps1" \
      --query 'value[].message' \
      --output tsv 2>&1)"
    rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      if (( attempt == DIAGNOSTICS_MAX_ATTEMPTS )); then
        printf '%s\n' "$diagnostics_output" >&2
        return $rc
      fi

      warn "Diagnostics invocation attempt ${attempt}/${DIAGNOSTICS_MAX_ATTEMPTS} failed; retrying in ${DIAGNOSTICS_RETRY_DELAY}s."
      sleep "$DIAGNOSTICS_RETRY_DELAY"
      attempt=$((attempt + 1))
      continue
    fi

    printf '%s\n' "$diagnostics_output"

    DIAG_PASS="$(parse_diag_count PASS "$diagnostics_output")"
    DIAG_WARN="$(parse_diag_count WARN "$diagnostics_output")"
    DIAG_FAIL="$(parse_diag_count FAIL "$diagnostics_output")"

    if [[ -n "$DIAG_FAIL" && "$DIAG_FAIL" == "0" ]]; then
      return 0
    fi

    if (( attempt == DIAGNOSTICS_MAX_ATTEMPTS )); then
      if [[ -z "$DIAG_FAIL" ]]; then
        error "Could not parse diagnostics summary after ${DIAGNOSTICS_MAX_ATTEMPTS} attempts; aborting before postdeploy."
      else
        error "Diagnostics reported FAIL=$DIAG_FAIL after ${DIAGNOSTICS_MAX_ATTEMPTS} attempts; aborting before postdeploy."
      fi
      return 1
    fi

    if [[ -z "$DIAG_FAIL" ]]; then
      warn "Diagnostics summary was not parseable on attempt ${attempt}/${DIAGNOSTICS_MAX_ATTEMPTS}; retrying in ${DIAGNOSTICS_RETRY_DELAY}s."
    else
      warn "Diagnostics reported FAIL=$DIAG_FAIL on attempt ${attempt}/${DIAGNOSTICS_MAX_ATTEMPTS}; retrying in ${DIAGNOSTICS_RETRY_DELAY}s because App Services may still be warming up after apply."
    fi

    sleep "$DIAGNOSTICS_RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

run_postdeploy_db() {
  TFVARS_FILE="$TFVARS_FILE" bash "$ROOT_DIR/scripts/postdeploy-db.sh" "$DB_TASK"
}

run_postdeploy_images() {
  TFVARS_FILE="$TFVARS_FILE" bash "$ROOT_DIR/scripts/postdeploy-storage-images.sh"
}

print_summary() {
  local phase_name

  printf '\nDeployment summary\n'
  printf '%s\n' '------------------'
  for phase_name in "${PHASE_ORDER[@]}"; do
    printf '%-24s %-8s %ss\n' "$phase_name" "${PHASE_STATUS[$phase_name]}" "${PHASE_DURATION[$phase_name]}"
  done

  printf '\nTFVARS: %s\n' "$TFVARS_FILE"
  printf 'Backend:%s\n' " $BACKEND_CONFIG_FILE"
  printf 'Plan:   %s\n' "$(display_plan_path)"

  if [[ -n "$RESOURCE_GROUP" && -n "$JUMPBOX_VM" ]]; then
    printf 'RG:     %s\n' "$RESOURCE_GROUP"
    printf 'Jumpbox:%s\n' " $JUMPBOX_VM"
  fi

  if [[ -n "$SP2_APP_FQDN" && -n "$SP2_ADMIN_FQDN" ]]; then
    printf 'MySQL:  app=%s admin=%s\n' "$SP2_APP_FQDN" "$SP2_ADMIN_FQDN"
  fi

  if [[ -n "$DIAG_FAIL" ]]; then
    printf 'Diag:   PASS=%s WARN=%s FAIL=%s\n' "${DIAG_PASS:-?}" "${DIAG_WARN:-?}" "$DIAG_FAIL"
  fi

  if [[ "$SUMMARY_MODE" == "plan-only" ]]; then
    printf '\nPlan creado sin apply. Para continuar manualmente:\n'
    printf 'terraform -chdir=terraform apply -input=false -lock-timeout=%q %q\n' "$TERRAFORM_LOCK_TIMEOUT" "$PLAN_FILE"
  fi

  printf '\nComandos utiles:\n'
  printf '  terraform -chdir=terraform output -json | jq '\''{resource_group_name, jumpbox_access, spoke2_mysql_fqdns, internal_urls}'\''\n'
  printf '  TFVARS_FILE=%q bash scripts/postdeploy-db.sh verify\n' "$TFVARS_FILE"
  printf '  TFVARS_FILE=%q bash scripts/postdeploy-storage-images.sh\n' "$TFVARS_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tfvars)
      [[ $# -ge 2 ]] || { error "Missing value for --tfvars"; exit 2; }
      TFVARS_FILE="$(resolve_path "$2")"
      shift 2
      ;;
    --backend-config)
      [[ $# -ge 2 ]] || { error "Missing value for --backend-config"; exit 2; }
      BACKEND_CONFIG_FILE="$(resolve_path "$2")"
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
    --skip-init)
      SKIP_INIT=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-diagnostics)
      SKIP_DIAGNOSTICS=true
      shift
      ;;
    --skip-db)
      SKIP_DB=true
      shift
      ;;
    --skip-images)
      SKIP_IMAGES=true
      shift
      ;;
    --db-task)
      [[ $# -ge 2 ]] || { error "Missing value for --db-task"; exit 2; }
      DB_TASK="$2"
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

case "$DB_TASK" in
  schema|seed|verify|all|reset-demo) ;;
  *)
    error "Invalid --db-task: $DB_TASK"
    exit 2
    ;;
esac

require_prerequisites
check_resource_group_state

if [[ "$SKIP_BUILD" == false ]]; then
  run_phase "build-prebuilts" run_build
else
  record_phase "build-prebuilts" "skipped" "0"
fi

if [[ "$SKIP_INIT" == false ]]; then
  run_phase "terraform-init" run_terraform_init
else
  record_phase "terraform-init" "skipped" "0"
fi

run_phase "terraform-validate" run_terraform_validate
run_phase "terraform-plan" run_terraform_plan

if [[ "$AUTO_APPROVE" == false ]]; then
  SUMMARY_MODE="plan-only"
  print_summary
  exit 0
fi

run_phase "terraform-apply" run_terraform_apply
run_phase "terraform-outputs" load_outputs

if [[ "$SKIP_DIAGNOSTICS" == false ]]; then
  run_phase "jumpbox-diagnostics" run_diagnostics
else
  record_phase "jumpbox-diagnostics" "skipped" "0"
fi

if [[ "$SKIP_DB" == false ]]; then
  run_phase "postdeploy-db" run_postdeploy_db
else
  record_phase "postdeploy-db" "skipped" "0"
fi

if [[ "$SKIP_IMAGES" == false ]]; then
  run_phase "postdeploy-images" run_postdeploy_images
else
  record_phase "postdeploy-images" "skipped" "0"
fi

print_summary