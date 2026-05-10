#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TFVARS_FILE="${TFVARS_FILE:-$TERRAFORM_DIR/main.tfvars}"
IMAGE_LIST_FILE="${IMAGE_LIST_FILE:-$ROOT_DIR/src/spoke2/list-images.txt}"
PYTHON_SCRIPT="$ROOT_DIR/scripts/postdeploy-storage-images.py"
TASK_SCRIPT="$ROOT_DIR/scripts/postdeploy-storage-images-task.ps1"

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

b64_text() {
  if base64 --help 2>&1 | grep -q -- '-w'; then
    printf '%s' "$1" | base64 -w0
  else
    printf '%s' "$1" | base64 | tr -d '\n'
  fi
}

require_command az
require_command awk
require_command base64
require_command jq
require_command sed
require_command terraform

if [[ ! -f "$IMAGE_LIST_FILE" ]]; then
  echo "Image list file not found: $IMAGE_LIST_FILE" >&2
  exit 1
fi

terraform_output="$(terraform -chdir="$TERRAFORM_DIR" output -json)"
resource_group="$(jq -r '.resource_group_name.value' <<<"$terraform_output")"
jumpbox_vm="$(jq -r '.jumpbox_access.value.vm_name' <<<"$terraform_output")"
mysql_host="$(jq -r '.spoke2_mysql_fqdns.value.app' <<<"$terraform_output")"
mysql_database="${MYSQL_APP_DATABASE:-$(read_tfvars_string app_database_name)}"
mysql_user="${MYSQL_ADMIN_USER:-$(read_tfvars_string mysql_administrator_login)}"
mysql_password="${MYSQL_ADMIN_PASSWORD:-$(read_tfvars_string mysql_administrator_password)}"

storage_state="$(terraform -chdir="$TERRAFORM_DIR" state show module.spoke2.azurerm_storage_account.documents)"
container_state="$(terraform -chdir="$TERRAFORM_DIR" state show module.spoke2.azapi_resource.documents_container)"
storage_account_name="${STORAGE_ACCOUNT_NAME:-$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' <<<"$storage_state" | head -n 1)}"
storage_account_url="${STORAGE_ACCOUNT_URL:-$(sed -n 's/^[[:space:]]*primary_blob_endpoint[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' <<<"$storage_state" | head -n 1)}"
storage_container="${STORAGE_CONTAINER_NAME:-$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' <<<"$container_state" | head -n 1)}"
storage_account_key="${STORAGE_ACCOUNT_KEY:-$(az storage account keys list --resource-group "$resource_group" --account-name "$storage_account_name" --query '[0].value' --output tsv)}"

if [[ -z "$resource_group" || "$resource_group" == "null" || -z "$jumpbox_vm" || "$jumpbox_vm" == "null" ]]; then
  echo "Terraform outputs do not include resource_group_name or jumpbox_access.vm_name." >&2
  exit 1
fi

if [[ -z "$storage_account_name" || -z "$storage_account_url" || -z "$storage_container" || -z "$storage_account_key" ]]; then
  echo "Could not resolve Storage Account values." >&2
  exit 1
fi

if [[ -z "$mysql_host" || "$mysql_host" == "null" || -z "$mysql_database" || -z "$mysql_user" || -z "$mysql_password" ]]; then
  echo "Could not resolve MySQL values." >&2
  exit 1
fi

echo "Running post-deploy image upload through jumpbox '$jumpbox_vm' in resource group '$resource_group'."
echo "Targets: storage=$storage_account_name/$storage_container, mysql=$mysql_host/$mysql_database"

wrapper_script="$(mktemp)"
trap 'rm -f "$wrapper_script"' EXIT

cat >"$wrapper_script" <<EOF
\$env:POSTDEPLOY_IMAGE_SCRIPT_B64 = '$(b64_file "$PYTHON_SCRIPT")'
\$env:POSTDEPLOY_IMAGE_URLS_B64 = '$(b64_file "$IMAGE_LIST_FILE")'
\$env:POSTDEPLOY_STORAGE_ACCOUNT_URL_B64 = '$(b64_text "$storage_account_url")'
\$env:POSTDEPLOY_STORAGE_ACCOUNT_KEY_B64 = '$(b64_text "$storage_account_key")'
\$env:POSTDEPLOY_STORAGE_CONTAINER_B64 = '$(b64_text "$storage_container")'
\$env:POSTDEPLOY_MYSQL_HOST_B64 = '$(b64_text "$mysql_host")'
\$env:POSTDEPLOY_MYSQL_DATABASE_B64 = '$(b64_text "$mysql_database")'
\$env:POSTDEPLOY_MYSQL_USER_B64 = '$(b64_text "$mysql_user")'
\$env:POSTDEPLOY_MYSQL_PASSWORD_B64 = '$(b64_text "$mysql_password")'
EOF

cat "$TASK_SCRIPT" >>"$wrapper_script"

az vm run-command invoke \
  --resource-group "$resource_group" \
  --name "$jumpbox_vm" \
  --command-id RunPowerShellScript \
  --scripts "@$wrapper_script" \
  --query 'value[].message' \
  --output tsv