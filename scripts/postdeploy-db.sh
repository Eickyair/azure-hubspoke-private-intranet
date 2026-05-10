#!/usr/bin/env bash
set -euo pipefail

TASK="${1:-all}"
case "$TASK" in
  schema|seed|verify|all|reset-demo) ;;
  *)
    echo "Usage: $0 [schema|seed|verify|all|reset-demo]" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="${TFVARS_FILE:-$TERRAFORM_DIR/main.tfvars}"
TASK_SCRIPT="$ROOT_DIR/scripts/postdeploy-db-task.ps1"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

read_tfvars_string() {
  local key="$1"
  awk -F '"' -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2; exit }' "$TFVARS_FILE"
}

b64_file() {
  if base64 --help 2>&1 | grep -q -- '-w'; then
    base64 -w0 "$1"
  else
    base64 "$1" | tr -d '\n'
  fi
}

require_command az
require_command jq
require_command terraform
require_command awk
require_command base64

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "Terraform tfvars file not found: $TFVARS_FILE" >&2
  exit 1
fi

terraform_output="$(terraform -chdir="$TERRAFORM_DIR" output -json)"

resource_group="$(jq -r '.resource_group_name.value' <<<"$terraform_output")"
jumpbox_vm="$(jq -r '.jumpbox_access.value.vm_name' <<<"$terraform_output")"
app_host="$(jq -r '.spoke2_mysql_fqdns.value.app' <<<"$terraform_output")"
admin_host="$(jq -r '.spoke2_mysql_fqdns.value.admin' <<<"$terraform_output")"

app_database="${MYSQL_APP_DATABASE:-$(read_tfvars_string app_database_name)}"
admin_database="${MYSQL_ADMIN_DATABASE:-$(read_tfvars_string admin_database_name)}"
mysql_user="${MYSQL_ADMIN_USER:-$(read_tfvars_string mysql_administrator_login)}"
mysql_password="${MYSQL_ADMIN_PASSWORD:-$(read_tfvars_string mysql_administrator_password)}"

if [[ -z "$resource_group" || "$resource_group" == "null" || -z "$jumpbox_vm" || "$jumpbox_vm" == "null" ]]; then
  echo "Terraform outputs do not include resource_group_name or jumpbox_access.vm_name." >&2
  exit 1
fi

if [[ -z "$app_host" || "$app_host" == "null" || -z "$admin_host" || "$admin_host" == "null" ]]; then
  echo "Terraform outputs do not include Spoke 2 MySQL FQDNs." >&2
  exit 1
fi

if [[ -z "$app_database" || -z "$admin_database" || -z "$mysql_user" || -z "$mysql_password" ]]; then
  echo "Could not read MySQL database names or credentials. Set MYSQL_APP_DATABASE, MYSQL_ADMIN_DATABASE, MYSQL_ADMIN_USER and MYSQL_ADMIN_PASSWORD if needed." >&2
  exit 1
fi

echo "Running post-deploy DB task '$TASK' through jumpbox '$jumpbox_vm' in resource group '$resource_group'."
echo "Targets: catalog=$app_host/$app_database, admin=$admin_host/$admin_database"

az vm run-command invoke \
  --resource-group "$resource_group" \
  --name "$jumpbox_vm" \
  --command-id RunPowerShellScript \
  --scripts "@$TASK_SCRIPT" \
  --parameters \
    "Task=$TASK" \
    "AppHost=$app_host" \
    "AdminHost=$admin_host" \
    "AppDatabase=$app_database" \
    "AdminDatabase=$admin_database" \
    "MysqlUser=$mysql_user" \
    "MysqlPassword=$mysql_password" \
    "AdminSchemaB64=$(b64_file "$ROOT_DIR/src/spoke2/db_init/01_intranet_schema.sql")" \
    "CatalogSchemaB64=$(b64_file "$ROOT_DIR/src/spoke2/db_init/02_catalog_schema.sql")" \
    "AdminSeedB64=$(b64_file "$ROOT_DIR/src/spoke2/db_init/03_admin_seed.sql")" \
    "CatalogSeedB64=$(b64_file "$ROOT_DIR/src/spoke2/db_init/04_catalog_seed.sql")" \
  --query 'value[].message' \
  --output tsv