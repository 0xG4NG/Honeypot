#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/local"
DOCKER_COMMON="${ROOT_DIR}/scripts/docker-common.sh"

source "${DOCKER_COMMON}"

run_docker_compose -f "${LOCAL_DIR}/docker-compose.yml" --env-file "${LOCAL_DIR}/.env" down -v
