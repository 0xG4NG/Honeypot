#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOFU_DIR="${ROOT_DIR}/opentofu"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
BOOTSTRAP_SCRIPT="${ROOT_DIR}/scripts/bootstrap-local.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $1" >&2
    exit 1
  fi
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local reply
  read -r -p "${label} [${default_value}]: " reply
  if [[ -z "${reply}" ]]; then
    printf '%s\n' "${default_value}"
  else
    printf '%s\n' "${reply}"
  fi
}

prompt_secret() {
  local label="$1"
  local reply
  read -r -s -p "${label}: " reply
  echo
  printf '%s\n' "${reply}"
}

bash "${BOOTSTRAP_SCRIPT}"

require_cmd tofu
require_cmd ansible-galaxy
require_cmd ansible-playbook

HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"
if [[ -z "${HCLOUD_TOKEN}" ]]; then
  HCLOUD_TOKEN="$(prompt_secret "Hetzner API token")"
fi

SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH:-$(prompt_default "Ruta a la clave privada SSH" "~/.ssh/id_ed25519")}"
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH/#\~/${HOME}}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-${SSH_PRIVATE_KEY_PATH}.pub}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH/#\~/${HOME}}"

if [[ ! -f "${SSH_PRIVATE_KEY_PATH}" ]]; then
  echo "No existe la clave privada: ${SSH_PRIVATE_KEY_PATH}" >&2
  exit 1
fi

if [[ ! -f "${SSH_PUBLIC_KEY_PATH}" ]]; then
  echo "No existe la clave publica: ${SSH_PUBLIC_KEY_PATH}" >&2
  exit 1
fi

PROJECT_NAME="${PROJECT_NAME:-$(prompt_default "Nombre del proyecto" "honeypot")}"
ENVIRONMENT="${ENVIRONMENT:-$(prompt_default "Entorno" "dev")}"
LOCATION="${LOCATION:-$(prompt_default "Location de Hetzner" "fsn1")}"
NETWORK_CIDR="${NETWORK_CIDR:-$(prompt_default "CIDR de red privada" "10.42.0.0/16")}"
SUBNET_CIDR="${SUBNET_CIDR:-$(prompt_default "CIDR de subred" "10.42.10.0/24")}"
ADMIN_USER="${ADMIN_USER:-$(prompt_default "Usuario admin para Ansible" "adminops")}"
ADMIN_SSH_PORT="${ADMIN_SSH_PORT:-$(prompt_default "Puerto SSH administrativo" "22222")}"
SERVER_TYPE="${SERVER_TYPE:-$(prompt_default "Server type Hetzner" "cx22")}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-$(prompt_secret "Password inicial de Grafana")}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(prompt_secret "Password del usuario Cowrie en PostgreSQL")}"

export TF_VAR_hcloud_token="${HCLOUD_TOKEN}"
export TF_VAR_ssh_public_key_path="${SSH_PUBLIC_KEY_PATH}"
export TF_VAR_project_name="${PROJECT_NAME}"
export TF_VAR_environment="${ENVIRONMENT}"
export TF_VAR_location="${LOCATION}"
export TF_VAR_network_cidr="${NETWORK_CIDR}"
export TF_VAR_subnet_cidr="${SUBNET_CIDR}"
export TF_VAR_admin_user="${ADMIN_USER}"
export TF_VAR_admin_ssh_port="${ADMIN_SSH_PORT}"
export TF_VAR_server_type="${SERVER_TYPE}"
export TF_VAR_grafana_admin_password="${GRAFANA_ADMIN_PASSWORD}"
export TF_VAR_postgres_password="${POSTGRES_PASSWORD}"

echo "Inicializando OpenTofu..."
(cd "${TOFU_DIR}" && tofu init)

echo "Provisionando infraestructura en Hetzner..."
(cd "${TOFU_DIR}" && tofu apply -auto-approve)

echo "Configurando nodos Debian con Ansible..."
(
  cd "${ANSIBLE_DIR}" && \
  ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
  ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
  ansible-playbook -i inventory.ini playbooks/site.yml --private-key "${SSH_PRIVATE_KEY_PATH}"
)

echo
echo "Despliegue completado."
echo "IP publica:"
(cd "${TOFU_DIR}" && tofu output public_ip)
