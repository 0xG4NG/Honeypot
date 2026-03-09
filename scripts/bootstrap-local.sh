#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
BOOTSTRAP_COMPONENTS="${BOOTSTRAP_COMPONENTS:-deploy}"

export DEBIAN_FRONTEND=noninteractive

PKG_CACHE_UPDATED=0

need_cmd() {
  ! command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_platform() {
  if [[ ! -r /etc/os-release ]]; then
    echo "No se puede detectar el sistema operativo local." >&2
    exit 1
  fi

  . /etc/os-release
  OS_ID="${ID}"
  OS_LIKE="${ID_LIKE:-}"
}

pkg_install() {
  case "${PKG_MANAGER}" in
    apt)
      run_as_root apt-get install -y "$@"
      ;;
    dnf)
      run_as_root dnf install -y "$@"
      ;;
    *)
      echo "Gestor de paquetes no soportado: ${PKG_MANAGER}" >&2
      exit 1
      ;;
  esac
}

update_pkg_cache() {
  if [[ "${PKG_CACHE_UPDATED}" -eq 1 ]]; then
    return
  fi

  case "${PKG_MANAGER}" in
    apt)
      run_as_root apt-get update
      ;;
    dnf)
      run_as_root dnf makecache
      ;;
    *)
      echo "Gestor de paquetes no soportado: ${PKG_MANAGER}" >&2
      exit 1
      ;;
  esac

  PKG_CACHE_UPDATED=1
}

ensure_base_packages() {
  update_pkg_cache

  case "${PKG_MANAGER}" in
    apt)
      pkg_install ca-certificates curl gpg lsb-release
      ;;
    dnf)
      pkg_install ca-certificates curl dnf-plugins-core gnupg2 tar
      ;;
  esac
}

ensure_docker_repo_apt() {
  local keyring="/etc/apt/keyrings/docker.asc"
  local repo_file="/etc/apt/sources.list.d/docker.list"
  local codename arch

  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"

  ensure_base_packages

  if [[ ! -f "${keyring}" ]]; then
    run_as_root install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | run_as_root tee "${keyring}" >/dev/null
    run_as_root chmod a+r "${keyring}"
  fi

  if [[ ! -f "${repo_file}" ]]; then
    printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/%s %s stable\n' \
      "${arch}" "${keyring}" "${OS_ID}" "${codename}" | run_as_root tee "${repo_file}" >/dev/null
  fi

  PKG_CACHE_UPDATED=0
}

ensure_docker_repo_dnf() {
  if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
    run_as_root dnf config-manager --add-repo "https://download.docker.com/linux/fedora/docker-ce.repo"
  fi

  PKG_CACHE_UPDATED=0
}

ensure_tofu_repo_apt() {
  local keyring="/etc/apt/keyrings/opentofu.gpg"
  local repo_file="/etc/apt/sources.list.d/opentofu.list"

  ensure_base_packages

  if [[ ! -f "${keyring}" ]]; then
    run_as_root install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor | run_as_root tee "${keyring}" >/dev/null
    run_as_root chmod a+r "${keyring}"
  fi

  printf 'deb [signed-by=%s] https://packages.opentofu.org/opentofu/tofu/any/ any main\n' \
    "${keyring}" | run_as_root tee "${repo_file}" >/dev/null

  PKG_CACHE_UPDATED=0
}

ensure_docker() {
  if need_cmd docker; then
    echo "Instalando Docker..."
    case "${PKG_MANAGER}" in
      apt)
        ensure_docker_repo_apt
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
      dnf)
        ensure_docker_repo_dnf
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
    esac
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Instalando plugin Docker Compose..."
    case "${PKG_MANAGER}" in
      apt)
        ensure_docker_repo_apt
        pkg_install docker-compose-plugin
        ;;
      dnf)
        ensure_docker_repo_dnf
        pkg_install docker-compose-plugin
        ;;
    esac
  fi

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker >/dev/null 2>&1 || true
  fi
}

ensure_ansible() {
  if need_cmd ansible-playbook || need_cmd ansible-galaxy; then
    echo "Instalando Ansible..."
    case "${PKG_MANAGER}" in
      apt)
        pkg_install ansible
        ;;
      dnf)
        pkg_install ansible-core
        ;;
    esac
  fi
}

ensure_tofu() {
  if [[ "${PKG_MANAGER}" != "apt" ]]; then
    echo "La instalacion automatica de OpenTofu solo esta soportada en Debian/Ubuntu por ahora." >&2
    exit 1
  fi

  if need_cmd tofu; then
    echo "Instalando OpenTofu..."
    ensure_tofu_repo_apt
    pkg_install tofu
  fi
}

install_ansible_collections() {
  echo "Instalando colecciones de Ansible..."
  (
    cd "${ANSIBLE_DIR}"
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
    ansible-galaxy collection install -r requirements.yml >/dev/null
  )
}

detect_platform

case "${OS_ID}" in
  debian|ubuntu)
    PKG_MANAGER="apt"
    ;;
  fedora)
    PKG_MANAGER="dnf"
    ;;
  *)
    if [[ "${OS_LIKE}" == *debian* ]]; then
      PKG_MANAGER="apt"
    elif [[ "${OS_LIKE}" == *fedora* ]] || [[ "${OS_LIKE}" == *rhel* ]]; then
      PKG_MANAGER="dnf"
    else
      echo "Sistema operativo no soportado: ${OS_ID}" >&2
      exit 1
    fi
    ;;
esac

if need_cmd sudo && [[ "$(id -u)" -ne 0 ]]; then
  echo "Falta el comando requerido: sudo" >&2
  exit 1
fi

ensure_base_packages

case "${BOOTSTRAP_COMPONENTS}" in
  local)
    ensure_docker
    ;;
  check)
    ensure_ansible
    ensure_docker
    install_ansible_collections
    ;;
  deploy)
    ensure_ansible
    ensure_docker
    ensure_tofu
    install_ansible_collections
    ;;
  *)
    echo "BOOTSTRAP_COMPONENTS no soportado: ${BOOTSTRAP_COMPONENTS}" >&2
    exit 1
    ;;
esac

echo "Dependencias locales listas."
