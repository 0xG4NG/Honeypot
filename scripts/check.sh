#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
LOCAL_DIR="${ROOT_DIR}/local"
BOOTSTRAP_SCRIPT="${ROOT_DIR}/scripts/bootstrap-local.sh"
DOCKER_COMMON="${ROOT_DIR}/scripts/docker-common.sh"

source "${DOCKER_COMMON}"

BOOTSTRAP_COMPONENTS=check bash "${BOOTSTRAP_SCRIPT}"

require_cmd ansible-playbook
require_cmd docker

bash -n "${ROOT_DIR}/scripts/deploy-hetzner.sh"
bash -n "${ROOT_DIR}/scripts/destroy-hetzner.sh"
bash -n "${ROOT_DIR}/scripts/test-local.sh"

printf '%s\n' '[honeypot_host]' 'stack ansible_connection=local private_ip=127.0.0.1 grafana_admin_password=testpass postgres_cowrie_password=testdbpass' > /tmp/honeypot-inventory.ini
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  ansible-playbook -i /tmp/honeypot-inventory.ini "${ANSIBLE_DIR}/playbooks/site.yml" --syntax-check

run_docker_compose -f "${LOCAL_DIR}/docker-compose.yml" --env-file "${LOCAL_DIR}/.env.example" config >/dev/null

echo "Checks completados."
