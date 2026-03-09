#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${REPO_OWNER:-0xG4NG}"
REPO_NAME="${REPO_NAME:-Honeypot}"
REPO_REF="${REPO_REF:-main}"
WORK_DIR="$(mktemp -d)"
ARCHIVE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REPO_REF}.tar.gz"

cleanup() {
  rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "Falta el comando requerido: curl" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "Falta el comando requerido: tar" >&2
  exit 1
fi

curl -fsSL "${ARCHIVE_URL}" | tar -xz -C "${WORK_DIR}" --strip-components=1

exec bash "${WORK_DIR}/scripts/test-local.sh"
