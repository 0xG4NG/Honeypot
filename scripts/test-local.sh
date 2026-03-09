#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/local"
BOOTSTRAP_SCRIPT="${ROOT_DIR}/scripts/bootstrap-local.sh"
DOCKER_COMMON="${ROOT_DIR}/scripts/docker-common.sh"

source "${DOCKER_COMMON}"

BOOTSTRAP_COMPONENTS=local bash "${BOOTSTRAP_SCRIPT}"

require_cmd docker
require_cmd curl

if ! run_docker_compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin no disponible" >&2
  exit 1
fi

if [[ ! -f "${LOCAL_DIR}/.env" ]]; then
  cp "${LOCAL_DIR}/.env.example" "${LOCAL_DIR}/.env"
fi

run_docker_compose -f "${LOCAL_DIR}/docker-compose.yml" --env-file "${LOCAL_DIR}/.env" up -d --build

SSH_PORT="$(sed -n 's/^SSH_PUBLIC_PORT=//p' "${LOCAL_DIR}/.env" | tail -n 1)"
SSH_PORT="${SSH_PORT:-2222}"

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

for _ in $(seq 1 40); do
  if bash -c "</dev/tcp/127.0.0.1/${SSH_PORT}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! bash -c "</dev/tcp/127.0.0.1/${SSH_PORT}" >/dev/null 2>&1; then
  echo "Cowrie no esta escuchando en 127.0.0.1:${SSH_PORT}" >&2
  echo "Revisa: docker compose -f ${LOCAL_DIR}/docker-compose.yml --env-file ${LOCAL_DIR}/.env ps" >&2
  echo "Y los logs: docker compose -f ${LOCAL_DIR}/docker-compose.yml --env-file ${LOCAL_DIR}/.env logs cowrie" >&2
  exit 1
fi

echo "Stack local levantada."
echo "Cowrie local: ssh -p ${SSH_PORT} root@127.0.0.1"
echo "Grafana: http://127.0.0.1:3000"
echo "Prometheus: http://127.0.0.1:9090"
