#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/local"
BOOTSTRAP_SCRIPT="${ROOT_DIR}/scripts/bootstrap-local.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $1" >&2
    exit 1
  fi
}

bash "${BOOTSTRAP_SCRIPT}"

require_cmd docker
require_cmd curl

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin no disponible" >&2
  exit 1
fi

if [[ ! -f "${LOCAL_DIR}/.env" ]]; then
  cp "${LOCAL_DIR}/.env.example" "${LOCAL_DIR}/.env"
fi

docker compose -f "${LOCAL_DIR}/docker-compose.yml" --env-file "${LOCAL_DIR}/.env" up -d --build

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:3000/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:9090/-/healthy" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Stack local levantada."
echo "Cowrie local: ssh -p 2222 root@127.0.0.1"
echo "Grafana: http://127.0.0.1:3000"
echo "Prometheus: http://127.0.0.1:9090"
