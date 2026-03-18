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
  TELEGRAM_BOT_TOKEN_CHIEF
  TELEGRAM_BOT_TOKEN_NEWS
  TELEGRAM_ALLOWED_USER_ID
  GATEWAY_BIND
  TAILSCALE_IP
  TAILSCALE_HOSTNAME
  OPENCLAW_WORKSPACE_ROOT
  BRAVE_API_KEY
  MINIFLUX_DB_PASS
  MINIFLUX_ADMIN_PASS
  MINIFLUX_API_KEY
)
# TAVILY_API_KEY and SERPER_API_KEY are optional — used by agents directly via HTTP,
# not by OpenClaw's native search integration. Deploy succeeds without them.
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
  log "Installing OpenClaw and mcporter (npm)…"
  sudo npm install -g openclaw@latest mcporter@latest
  log "Installing Python dependencies (MCP server)…"
  # python3-requests is in apt; mcp is pip-only and requires --break-system-packages
  # on Debian/Ubuntu 22.04+ (PEP 668 externally-managed-environment restriction).
  sudo apt-get install -y -q python3-requests
  sudo pip3 install --break-system-packages --quiet mcp uvicorn
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
  rsync -a --exclude='MEMORY.md' --exclude='memory/' --exclude='.learnings/' "${SRC}/" "${DEST}/"

  # Seed MEMORY.md only if it doesn't exist yet (first deploy)
  if [[ ! -f "${DEST}/MEMORY.md" ]]; then
    cp "${SRC}/MEMORY.md" "${DEST}/MEMORY.md"
    log "  ${AGENT}: seeded MEMORY.md (first deploy)"
  fi

  # Seed .learnings/ only if it doesn't exist yet (first deploy)
  # Excluded from rsync above to preserve runtime error/learning logs on re-deploy.
  if [[ ! -d "${DEST}/.learnings" ]]; then
    mkdir -p "${DEST}/.learnings"
    cp "${SRC}/.learnings/"*.md "${DEST}/.learnings/" 2>/dev/null || true
    log "  ${AGENT}: seeded .learnings/ (first deploy)"
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

# ── Sync scripts (MCP servers) to workspace ──────────────────────────────────
log "Syncing scripts → ${OPENCLAW_WORKSPACE_ROOT}/scripts…"
rsync -a "${REPO_DIR}/scripts/" "${OPENCLAW_WORKSPACE_ROOT}/scripts/"
log "  scripts: synced → ${OPENCLAW_WORKSPACE_ROOT}/scripts"

# ── Render openclaw.json from template ───────────────────────────────────────
log "Rendering openclaw.json from template…"
OPENCLAW_CONFIG="${OPENCLAW_WORKSPACE_ROOT}/openclaw.json"
envsubst < "${REPO_DIR}/openclaw.json.template" > "${OPENCLAW_CONFIG}"
log "Wrote ${OPENCLAW_CONFIG}"

# ── Write ~/.openclaw/.env (daemon-safe env vars) ─────────────────────────────
# OpenClaw runs as a systemd daemon and won't inherit interactive shell env vars.
# Krill (OpenClaw support, 2026-02-17): put secrets in ~/.openclaw/.env and
# restart with `openclaw gateway restart`.
log "Writing ~/.openclaw/.env…"
mkdir -p "${HOME}/.openclaw"
cat > "${HOME}/.openclaw/.env" <<EOF
MINIFLUX_API_KEY=${MINIFLUX_API_KEY}
MINIFLUX_URL=http://localhost:8080
MCP_HOST=127.0.0.1
MCP_PORT=8765
EOF
chmod 600 "${HOME}/.openclaw/.env"
log "Wrote ~/.openclaw/.env"

# ── Write ~/.mcporter/mcporter.json (MCP client config) ───────────────────────
# mcporter is OpenClaw's MCP client layer. Config lives at ~/.mcporter/mcporter.json.
# Schema uses the standard MCP mcpServers format (same as Claude Desktop).
# If mcporter uses a different top-level key, run `mcporter config add miniflux …`
# and inspect the output to confirm — then update this block accordingly.
log "Writing ~/.mcporter/mcporter.json…"
mkdir -p "${HOME}/.mcporter"
MCP_SCRIPT="${OPENCLAW_WORKSPACE_ROOT}/scripts/miniflux_mcp_server.py"
MCP_PORT="${MCP_PORT:-8765}"
cat > "${HOME}/.mcporter/mcporter.json" <<EOF
{
  "mcpServers": {
    "miniflux": {
      "url": "http://127.0.0.1:${MCP_PORT}/sse"
    }
  }
}
EOF
chmod 600 "${HOME}/.mcporter/mcporter.json"
log "Wrote ~/.mcporter/mcporter.json (miniflux MCP SSE → http://127.0.0.1:${MCP_PORT}/sse)"

# ── Install miniflux-mcp systemd service ─────────────────────────────────────
log "Installing miniflux-mcp systemd service…"
sudo tee /etc/systemd/system/miniflux-mcp.service > /dev/null <<EOF
[Unit]
Description=Miniflux MCP Server (SSE)
After=network.target

[Service]
Type=simple
User=${USER}
EnvironmentFile=${HOME}/.openclaw/.env
ExecStart=/usr/bin/python3 ${MCP_SCRIPT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload

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
restart_service "miniflux-mcp"
log "Miniflux MCP SSE server running on http://127.0.0.1:${MCP_PORT}/sse"
# Reload mcporter config without a full service restart (picks up mcporter.json changes).
if command -v openclaw >/dev/null 2>&1; then
  openclaw gateway restart || log "⚠ 'openclaw gateway restart' failed — check gateway logs."
fi

# ── Docker Compose (Miniflux + PostgreSQL) ───────────────────────────────────
if command -v docker >/dev/null 2>&1 && [[ -f "${REPO_DIR}/docker-compose.yml" ]]; then
  log "Starting Docker services..."
  cd "${REPO_DIR}"
  docker compose up -d
  sleep 3
  if docker compose ps | grep -qE "running|Up"; then
    log "✓ Miniflux running at http://localhost:8080"
    log "  First run: Settings → API Keys → create key → add to .env as MINIFLUX_API_KEY"
  else
    log "⚠ Docker Compose may not have started cleanly — check: docker compose logs"
  fi
fi

# ── Print access info ─────────────────────────────────────────────────────────
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

log ""
log "Deployment complete."
log ""
log "  Telegram bots  → @chief_bot (Chief of Staff) / @news_bot (News)"
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
