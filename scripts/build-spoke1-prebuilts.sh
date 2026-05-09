#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_ROOT="$ROOT_DIR/src/spoke1"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/terraform/.terraform-build/prebuilt}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TARGET_PLATFORM="${TARGET_PLATFORM:-manylinux2014_x86_64}"
TARGET_PYTHON_VERSION="${TARGET_PYTHON_VERSION:-3.11}"

services=(webapp admin api)

usage() {
  printf 'Usage: %s [service...]\n' "$(basename "$0")"
  printf '\nBuild prebuilt ZIP packages for spoke1 App Services.\n'
  printf 'Default services: webapp admin api\n'
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

hash_file() {
  sha256sum "$1" | awk '{print $1}'
}

source_hash() {
  local service_dir="$1"
  local main_hash requirements_hash startup_hash

  main_hash="$(hash_file "$service_dir/main.py")"
  requirements_hash="$(hash_file "$service_dir/requirements.txt")"

  if [[ -f "$service_dir/startup.sh" ]]; then
    startup_hash="$(hash_file "$service_dir/startup.sh")"
  else
    startup_hash=""
  fi

  printf '%s:%s:%s' "$main_hash" "$requirements_hash" "$startup_hash" | sha256sum | awk '{print $1}'
}

copy_source() {
  local service_dir="$1"
  local build_dir="$2"

  cp "$service_dir/main.py" "$build_dir/main.py"
  cp "$service_dir/requirements.txt" "$build_dir/requirements.txt"

  if [[ -f "$service_dir/startup.sh" ]]; then
    cp "$service_dir/startup.sh" "$build_dir/startup.sh"
  fi
}

build_service() {
  local service="$1"
  local service_dir="$SRC_ROOT/$service"
  local hash build_dir package_name package_path package_size

  if [[ ! -d "$service_dir" ]]; then
    printf 'Unknown service: %s\n' "$service" >&2
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
  printf '%-6s %s %s %s\n' "$service" "$hash" "$package_size" "$package_path"
}

require_command sha256sum
require_command awk
require_command zip
"$PYTHON_BIN" -m pip --version >/dev/null

mkdir -p "$OUT_DIR"
printf 'service hash                                                             bytes path\n'
printf '%s\n' '------ ---------------------------------------------------------------- ----- ----'
for service in "${services[@]}"; do
  build_service "$service"
done

rm -rf "$OUT_DIR/.work"
