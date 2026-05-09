#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_ROOT="$ROOT_DIR/src/spoke1"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/terraform/.terraform-build/prebuilt}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TARGET_PLATFORM="${TARGET_PLATFORM:-manylinux2014_x86_64}"
TARGET_PYTHON_VERSION="${TARGET_PYTHON_VERSION:-3.11}"

services=(webapp api admin admin-api)

declare -A SERVICE_PATHS=(
  [webapp]="catalog/webapp"
  [api]="catalog/api"
  [admin]="admin/webapp"
  [admin-api]="admin/api"
)

usage() {
  printf 'Usage: %s [service...]\n' "$(basename "$0")"
  printf '\nBuild prebuilt ZIP packages for spoke1 App Services.\n'
  printf 'Default services: webapp api admin admin-api\n'
  printf '\nEnvironment overrides:\n'
  printf '  OUT_DIR=%s\n' "$OUT_DIR"
  printf '  PYTHON_BIN=%s\n' "$PYTHON_BIN"
  printf '  TARGET_PLATFORM=%s\n' "$TARGET_PLATFORM"
  printf '  TARGET_PYTHON_VERSION=%s\n' "$TARGET_PYTHON_VERSION"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  services=("$@")
fi

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
}

source_hash() {
  local service_dir="$1"
  (
    cd "$service_dir"
    local parts=()
    local file
    while IFS= read -r file; do
      parts+=("${file#./}:$(sha256sum "$file" | awk '{print $1}')")
    done < <(find . -type f \
      ! -name 'Dockerfile' \
      ! -name '*.pyc' \
      ! -path '*/__pycache__/*' \
      | LC_ALL=C sort)

    local joined
    joined="$(IFS=:; printf '%s' "${parts[*]}")"
    printf '%s' "$joined" | sha256sum | awk '{print $1}'
  )
}

copy_source() {
  local service_dir="$1"
  local build_dir="$2"
  (
    cd "$service_dir"
    find . -type f \
      ! -name 'Dockerfile' \
      ! -name '*.pyc' \
      ! -path '*/__pycache__/*' \
      -print0 \
      | while IFS= read -r -d '' file; do
          install -D "$file" "$build_dir/${file#./}"
        done
  )
}

build_service() {
  local service="$1"
  local relative_path="${SERVICE_PATHS[$service]:-}"
  local service_dir="$SRC_ROOT/$relative_path"
  local hash build_dir package_name package_path package_size

  if [[ -z "$relative_path" || ! -d "$service_dir" ]]; then
    printf 'Unknown service: %s\n' "$service" >&2
    exit 1
  fi

  if [[ ! -f "$service_dir/main.py" || ! -f "$service_dir/requirements.txt" ]]; then
    printf 'Missing main.py or requirements.txt for %s at %s\n' "$service" "$service_dir" >&2
    exit 1
  fi

  hash="$(source_hash "$service_dir")"
  build_dir="$OUT_DIR/.work/$service"
  package_name="${service}-prebuilt-${hash}.zip"
  package_path="$OUT_DIR/$package_name"

  rm -rf "$build_dir" "$package_path"
  mkdir -p "$build_dir/packages" "$OUT_DIR"

  copy_source "$service_dir" "$build_dir"

  "$PYTHON_BIN" -m pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    --no-compile \
    --requirement "$service_dir/requirements.txt" \
    --target "$build_dir/packages" \
    --platform "$TARGET_PLATFORM" \
    --implementation cp \
    --python-version "$TARGET_PYTHON_VERSION" \
    --only-binary=:all: \
    --quiet

  find "$build_dir" \
    \( -name '__pycache__' -o -name '*.pyc' -o -name '*.pyo' \) \
    -exec rm -rf {} +

  (
    cd "$build_dir"
    find . -type f | LC_ALL=C sort | zip -q -X "$package_path" -@
  )

  package_size="$(wc -c < "$package_path" | tr -d ' ')"
  printf '%-9s %s %s %s\n' "$service" "$hash" "$package_size" "$package_path"
}

require_command sha256sum
require_command awk
require_command zip
require_command install
"$PYTHON_BIN" -m pip --version >/dev/null

mkdir -p "$OUT_DIR"
printf 'service   hash                                                             bytes path\n'
printf '%s\n' '--------- ---------------------------------------------------------------- ----- ----'
for service in "${services[@]}"; do
  build_service "$service"
done

rm -rf "$OUT_DIR/.work"
