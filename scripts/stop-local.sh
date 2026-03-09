#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/local"

if ! command -v docker >/dev/null 2>&1; then
  echo "Falta el comando requerido: docker" >&2
  exit 1
fi

docker compose -f "${LOCAL_DIR}/docker-compose.yml" --env-file "${LOCAL_DIR}/.env" down -v
