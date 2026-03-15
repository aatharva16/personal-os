#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Personal AI OS GitOps Deployment Script
#
# Pulls the latest changes from GitHub, syncs agent workspaces,
# renders openclaw.json from the template, and restarts all services.
#
# Run on the Hetzner VM as clawuser:
#   ./deploy.sh [--branch <branch>] [--skip-install]
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="${BRANCH:-main}"
NODE_MIN_VERSION=22

AGENTS=("health" "stocks" "email")

# ── Parse args ────────────────────────────────────────────────────────────────
SKIP_INSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)        BRANCH="$2"; shift 2 ;;
    --skip-install)  SKIP_INSTALL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log()   { echo "[deploy] $*"; }
error() { echo "[deploy] ERROR: $*" >&2; exit 1; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
log "Pre-flight checks…"

command -v git     >/dev/null 2>&1 || error "git is not installed."
command -v node    >/dev/null 2>&1 || error "Node.js is not installed."
command -v python3 >/dev/null 2>&1 || error "Python 3 is not installed."
command -v envsubst >/dev/null 2>&1 || error "envsubst not found. Install gettext: apt install gettext-base"

NODE_VERSION=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
(( NODE_VERSION >= NODE_MIN_VERSION )) || \
  error "Node.js v${NODE_MIN_VERSION}+ required (found v${NODE_VERSION})."

[[ -f "${REPO_DIR}/.env" ]] || \
  error ".env not found. Copy .env.example and fill in your secrets."

# Load env vars (needed for envsubst and validation)
set -a; source "${REPO_DIR}/.env"; set +a

# Validate required vars
REQUIRED_VARS=(
  NADIRCLAW_PORT
  NADIRCLAW_SIMPLE_MODEL
  NADIRCLAW_COMPLEX_MODEL
  TELEGRAM_BOT_TOKEN_HEALTH
  TELEGRAM_BOT_TOKEN_STOCKS
  TELEGRAM_BOT_TOKEN_EMAIL
  TELEGRAM_ALLOWED_USER_ID
  OPENCLAW_WORKSPACE_ROOT
)
for VAR in "${REQUIRED_VARS[@]}"; do
  [[ -n "${!VAR:-}" ]] || error "Required env var '${VAR}' is not set in .env"
done

# ── Pull latest code ──────────────────────────────────────────────────────────
log "Pulling latest code (origin/${BRANCH})…"
cd "${REPO_DIR}"
git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git reset --hard "origin/${BRANCH}"
log "At commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty='%s')"

# ── Install dependencies ──────────────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == false ]]; then
  log "Installing OpenClaw (npm)…"
  npm install -g openclaw@latest

  log "Installing NadirClaw (pip)…"
  pip3 install --upgrade nadirclaw
else
  log "Skipping installs (--skip-install)."
fi

# ── Sync agent workspaces ─────────────────────────────────────────────────────
log "Syncing agent workspaces → ${OPENCLAW_WORKSPACE_ROOT}…"
mkdir -p "${OPENCLAW_WORKSPACE_ROOT}"

for AGENT in "${AGENTS[@]}"; do
  SRC="${REPO_DIR}/agents/${AGENT}"
  DEST="${OPENCLAW_WORKSPACE_ROOT}/workspace-${AGENT}"
  mkdir -p "${DEST}/memory"

  # Sync workspace files (preserve MEMORY.md and memory/ if they already exist
  # on the VM — we don't want to overwrite runtime-updated memory with stubs)
  rsync -a --exclude='MEMORY.md' --exclude='memory/' "${SRC}/" "${DEST}/"

  # Seed MEMORY.md only if it doesn't exist yet (first deploy)
  if [[ ! -f "${DEST}/MEMORY.md" ]]; then
    cp "${SRC}/MEMORY.md" "${DEST}/MEMORY.md"
    log "  ${AGENT}: seeded MEMORY.md (first deploy)"
  fi

  # Symlink the shared USER.md into every workspace
  ln -sf "${OPENCLAW_WORKSPACE_ROOT}/USER.md" "${DEST}/USER.md"

  log "  ${AGENT}: workspace synced → ${DEST}"
done

# Copy shared USER.md (only if not customised yet)
SHARED_USER_MD="${OPENCLAW_WORKSPACE_ROOT}/USER.md"
if [[ ! -f "${SHARED_USER_MD}" ]]; then
  cp "${REPO_DIR}/agents/USER.md" "${SHARED_USER_MD}"
  log "Seeded shared USER.md (fill it in to personalise all agents)."
fi

# ── Render openclaw.json from template ───────────────────────────────────────
log "Rendering openclaw.json from template…"
OPENCLAW_CONFIG="${OPENCLAW_WORKSPACE_ROOT}/openclaw.json"
envsubst < "${REPO_DIR}/openclaw.json.template" > "${OPENCLAW_CONFIG}"
log "Wrote ${OPENCLAW_CONFIG}"

# ── Restart services ──────────────────────────────────────────────────────────
restart_service() {
  local SVC="$1"
  if systemctl is-active --quiet "${SVC}"; then
    sudo systemctl restart "${SVC}"
  else
    sudo systemctl start "${SVC}"
  fi
  sudo systemctl enable "${SVC}" 2>/dev/null || true
  sleep 2
  if systemctl is-active --quiet "${SVC}"; then
    log "✓ ${SVC} is running."
  else
    error "${SVC} failed to start. Check: journalctl -u ${SVC} -n 50"
  fi
}

log "Restarting services…"
restart_service "nadirclaw"
restart_service "personal-os"

log "Deployment complete."
