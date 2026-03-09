#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${ROOT_DIR}/ansible"

export DEBIAN_FRONTEND=noninteractive

APT_UPDATED=0

need_cmd() {
  ! command -v "$1" >/dev/null 2>&1
}

apt_runner() {
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get "$@"
  else
    sudo apt-get "$@"
  fi
}

update_apt_cache() {
  if [[ "${APT_UPDATED}" -eq 0 ]]; then
    apt_runner update
    APT_UPDATED=1
  fi
}

install_apt_packages() {
  update_apt_cache
  apt_runner install -y "$@"
}

ensure_base_packages() {
  install_apt_packages ca-certificates curl gpg lsb-release
}

ensure_docker_repo() {
  local keyring="/etc/apt/keyrings/docker.asc"
  local repo_file="/etc/apt/sources.list.d/docker.list"
  local distro codename arch

  distro="$(. /etc/os-release && printf '%s' "${ID}")"
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"

  ensure_base_packages

  if [[ ! -f "${keyring}" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${distro}/gpg" -o "${keyring}"
      chmod a+r "${keyring}"
    else
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${distro}/gpg" | sudo tee "${keyring}" >/dev/null
      sudo chmod a+r "${keyring}"
    fi
  fi

  if [[ ! -f "${repo_file}" ]]; then
    printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/%s %s stable\n' \
      "${arch}" "${keyring}" "${distro}" "${codename}" | \
      if [[ "$(id -u)" -eq 0 ]]; then tee "${repo_file}" >/dev/null; else sudo tee "${repo_file}" >/dev/null; fi
  fi

  APT_UPDATED=0
}

ensure_tofu_repo() {
  local keyring="/etc/apt/keyrings/opentofu.gpg"
  local repo_file="/etc/apt/sources.list.d/opentofu.list"

  ensure_base_packages

  if [[ ! -f "${keyring}" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor -o "${keyring}"
      chmod a+r "${keyring}"
    else
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor | sudo tee "${keyring}" >/dev/null
      sudo chmod a+r "${keyring}"
    fi
  fi

  # OpenTofu publishes a generic apt repo; distro/codename-specific entries can
  # resolve successfully but still expose no "tofu" package on newer releases.
  printf 'deb [signed-by=%s] https://packages.opentofu.org/opentofu/tofu/any/ any main\n' \
    "${keyring}" | \
    if [[ "$(id -u)" -eq 0 ]]; then tee "${repo_file}" >/dev/null; else sudo tee "${repo_file}" >/dev/null; fi

  APT_UPDATED=0
}

if [[ ! -f /etc/debian_version ]]; then
  echo "bootstrap-local.sh solo soporta Debian/Ubuntu por ahora." >&2
  exit 1
fi

if need_cmd sudo && [[ "$(id -u)" -ne 0 ]]; then
  echo "Falta el comando requerido: sudo" >&2
  exit 1
fi

ensure_base_packages

if need_cmd ansible-playbook || need_cmd ansible-galaxy; then
  echo "Instalando Ansible..."
  install_apt_packages ansible
fi

if need_cmd docker; then
  echo "Instalando Docker..."
  ensure_docker_repo
  install_apt_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Instalando plugin Docker Compose..."
  ensure_docker_repo
  install_apt_packages docker-compose-plugin
fi

if need_cmd tofu; then
  echo "Instalando OpenTofu..."
  ensure_tofu_repo
  install_apt_packages tofu
fi

echo "Instalando colecciones de Ansible..."
(
  cd "${ANSIBLE_DIR}"
  ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
  ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
  ansible-galaxy collection install -r requirements.yml >/dev/null
)

echo "Dependencias locales listas."
