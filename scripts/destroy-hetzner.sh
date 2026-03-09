#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOFU_DIR="${ROOT_DIR}/opentofu"

if ! command -v tofu >/dev/null 2>&1; then
  echo "Falta el comando requerido: tofu" >&2
  exit 1
fi

HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"
if [[ -z "${HCLOUD_TOKEN}" ]]; then
  read -r -s -p "Hetzner API token: " HCLOUD_TOKEN
  echo
fi

export TF_VAR_hcloud_token="${HCLOUD_TOKEN}"

cd "${TOFU_DIR}"
tofu destroy
