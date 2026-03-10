#!/usr/bin/env bash
# deploy.sh — Despliega el honeypot completo en Hetzner Cloud.
# Uso: ./scripts/deploy.sh [--destroy]
# Requiere: tofu, ansible-playbook, ansible-galaxy
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOFU_DIR="${ROOT_DIR}/opentofu"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
TFVARS="${TOFU_DIR}/terraform.tfvars"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}${BOLD}[deploy]${RESET} $*"; }
ok()   { echo -e "${GREEN}✔ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()  { echo -e "${RED}✖ $*${RESET}" >&2; exit 1; }

# ─── Comprobaciones previas ───────────────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in tofu ansible-playbook ansible-galaxy; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Faltan dependencias: ${missing[*]}\nInstálalas antes de continuar."
  fi
}

check_tfvars() {
  if [[ ! -f "${TFVARS}" ]]; then
    warn "No existe terraform.tfvars. Copiando el ejemplo..."
    cp "${TOFU_DIR}/terraform.tfvars.example" "${TFVARS}"
    die "Edita ${TFVARS} con tus valores reales (hcloud_token, ssh_public_key_path, etc.) y vuelve a ejecutar."
  fi
}

# ─── Destrucción ──────────────────────────────────────────────────────────────
destroy() {
  log "Destruyendo infraestructura en Hetzner..."
  cd "${TOFU_DIR}"
  tofu destroy -auto-approve
  ok "Infraestructura destruida."
}

# ─── Despliegue ───────────────────────────────────────────────────────────────
deploy() {
  # 1. Inicializar OpenTofu (solo si hace falta)
  log "Paso 1/4 — Inicializando OpenTofu..."
  cd "${TOFU_DIR}"
  tofu init -input=false
  ok "OpenTofu inicializado."

  # 2. Aplicar infraestructura
  log "Paso 2/4 — Aplicando infraestructura (tofu apply)..."
  tofu apply -input=false -auto-approve
  ok "Infraestructura creada."

  # Obtener la IP pública del output de Tofu
  PUBLIC_IP="$(tofu output -raw public_ip)"
  INVENTORY_FILE="$(tofu output -raw inventory_file)"
  ok "IP pública del servidor: ${PUBLIC_IP}"
  ok "Inventario generado en: ${INVENTORY_FILE}"

  # 3. Instalar colecciones de Ansible
  log "Paso 3/4 — Instalando colecciones de Ansible..."
  cd "${ANSIBLE_DIR}"
  ansible-galaxy collection install -r requirements.yml --upgrade
  ok "Colecciones instaladas."

  # 4. Ejecutar el playbook
  log "Paso 4/4 — Configurando el servidor con Ansible..."
  ansible-playbook playbooks/site.yml -i "${INVENTORY_FILE}"
  ok "Playbook completado."

  echo ""
  echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}  ✔ Honeypot desplegado correctamente   ${RESET}"
  echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
  echo -e "  IP del servidor : ${BOLD}${PUBLIC_IP}${RESET}"
  echo -e "  Honeypot SSH    : ${BOLD}${PUBLIC_IP}:22${RESET}"
  echo -e "  Admin SSH       : ${BOLD}${PUBLIC_IP}:22222${RESET}"
  echo -e "  Grafana         : ${BOLD}http://${PUBLIC_IP}:3000${RESET}"
  echo ""
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────
check_deps

if [[ "${1:-}" == "--destroy" ]]; then
  check_tfvars
  destroy
else
  check_tfvars
  deploy
fi
