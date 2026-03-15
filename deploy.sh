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

AGENTS=(chief news)

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

command -v git      >/dev/null 2>&1 || error "git is not installed."
command -v node     >/dev/null 2>&1 || error "Node.js is not installed."
command -v envsubst >/dev/null 2>&1 || error "envsubst not found. Run: sudo apt install gettext-base"

NODE_VERSION=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
(( NODE_VERSION >= NODE_MIN_VERSION )) || \
  error "Node.js v${NODE_MIN_VERSION}+ required (found v${NODE_VERSION})."

[[ -f "${REPO_DIR}/.env" ]] || \
  error ".env not found. Copy .env.example and fill in your secrets."

# Load env vars
set -a; source "${REPO_DIR}/.env"; set +a

# Validate required vars
REQUIRED_VARS=(
  OPENROUTER_API_KEY
  HEARTBEAT_MODEL_ID
  TELEGRAM_BOT_TOKEN
  TELEGRAM_ALLOWED_USER_ID
  GATEWAY_BIND
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
else
  log "Skipping installs (--skip-install)."
fi

# ── Sync agent workspaces ─────────────────────────────────────────────────────
log "Syncing agent workspaces → ${OPENCLAW_WORKSPACE_ROOT}…"
mkdir -p "${OPENCLAW_WORKSPACE_ROOT}"

for AGENT in "${AGENTS[@]}"; do
  SRC="${REPO_DIR}/agents/${AGENT}"
  DEST="${OPENCLAW_WORKSPACE_ROOT}/workspace-${AGENT}"
  mkdir -p "${DEST}/memory" "${DEST}/skills"

  # Sync workspace files.
  # MEMORY.md and memory/ are excluded — they grow at runtime on the VM
  # and must not be overwritten by stubs from the repo on re-deploys.
  rsync -a --exclude='MEMORY.md' --exclude='memory/' "${SRC}/" "${DEST}/"

  # Seed MEMORY.md only if it doesn't exist yet (first deploy)
  if [[ ! -f "${DEST}/MEMORY.md" ]]; then
    cp "${SRC}/MEMORY.md" "${DEST}/MEMORY.md"
    log "  ${AGENT}: seeded MEMORY.md (first deploy)"
  fi

  # Symlink shared USER.md into every workspace
  ln -sf "${OPENCLAW_WORKSPACE_ROOT}/USER.md" "${DEST}/USER.md"

  log "  ${AGENT}: synced → ${DEST}"
done

# Copy shared USER.md on first deploy
SHARED_USER_MD="${OPENCLAW_WORKSPACE_ROOT}/USER.md"
if [[ ! -f "${SHARED_USER_MD}" ]]; then
  cp "${REPO_DIR}/agents/USER.md" "${SHARED_USER_MD}"
  log "Seeded shared USER.md — fill it in to personalise all agents."
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
restart_service "personal-os"

# Ensure the heartbeat timer is enabled and running.
log "Enabling heartbeat timer…"
sudo systemctl enable personal-os-heartbeat.timer 2>/dev/null || true
if systemctl is-active --quiet "personal-os-heartbeat.timer"; then
  sudo systemctl restart "personal-os-heartbeat.timer"
else
  sudo systemctl start "personal-os-heartbeat.timer"
fi
if systemctl is-active --quiet "personal-os-heartbeat.timer"; then
  log "✓ personal-os-heartbeat.timer is running."
  log "  Next heartbeat: $(systemctl show personal-os-heartbeat.timer --property=NextElapseUSecRealtime --value | xargs -I{} date -d @$(({}/1000000)) 2>/dev/null || echo 'see: systemctl status personal-os-heartbeat.timer')"
else
  error "personal-os-heartbeat.timer failed to start. Check: journalctl -u personal-os-heartbeat -n 50"
fi

# ── Print access info ─────────────────────────────────────────────────────────
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

log ""
log "Deployment complete."
log ""
log "  Telegram bot   → message it (Chief of Staff handles all routing)"
if [[ -n "${TAILSCALE_IP}" ]]; then
  log "  Web Control UI → http://${TAILSCALE_IP}:18789"
  log "                   (paste gateway token from startup logs when prompted)"
else
  log "  Web Control UI → Tailscale not detected. Once connected:"
  log "                   http://<tailscale-ip>:18789"
  log "  Tailscale setup → curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up"
  log "  Note: set GATEWAY_BIND=0.0.0.0 in .env for Tailscale access"
fi
log ""
