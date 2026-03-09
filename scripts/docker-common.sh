#!/usr/bin/env bash

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $1" >&2
    exit 1
  fi
}

run_docker() {
  require_cmd docker

  if docker info >/dev/null 2>&1; then
    docker "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo docker "$@"
    return
  fi

  echo "Docker requiere permisos elevados y no hay sudo disponible." >&2
  exit 1
}

run_docker_compose() {
  run_docker compose "$@"
}
