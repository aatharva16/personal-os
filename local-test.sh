#!/usr/bin/env bash
# =============================================================================
# local-test.sh — Personal AI OS Local E2E Test
#
# Starts OpenClaw on your local machine (no systemd, no VM).
# Your Telegram bots will respond to messages in real time.
#
# Prerequisites:
#   - .env file populated with real secrets (copy .env.example and fill in)
#   - Node.js v22+, envsubst (apt install gettext-base)
#
# Usage:
#   ./local-test.sh [--skip-install]
#
# Press Ctrl+C to stop and clean up.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_WORKSPACE="${REPO_DIR}/.test-workspace"
NODE_MIN_VERSION=22

AGENTS=(chief news)

# ── Parse args ────────────────────────────────────────────────────────────────
SKIP_INSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-install) SKIP_INSTALL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log()   { echo "[test] $*"; }
error() { echo "[test] ERROR: $*" >&2; exit 1; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
log "Pre-flight checks…"

command -v node     >/dev/null 2>&1 || error "Node.js is not installed."
command -v envsubst >/dev/null 2>&1 || error "envsubst not found. Run: sudo apt install gettext-base"

NODE_VERSION=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
(( NODE_VERSION >= NODE_MIN_VERSION )) || \
  error "Node.js v${NODE_MIN_VERSION}+ required (found v${NODE_VERSION})."

[[ -f "${REPO_DIR}/.env" ]] || \
  error ".env not found. Run: cp .env.example .env  then fill in your secrets."

# Load and validate env vars
set -a; source "${REPO_DIR}/.env"; set +a

REQUIRED_VARS=(
  OPENROUTER_API_KEY
  HEARTBEAT_MODEL_ID
  TELEGRAM_BOT_TOKEN_CHIEF
  TELEGRAM_BOT_TOKEN_NEWS
  TELEGRAM_ALLOWED_USER_ID
  TAVILY_API_KEY
  SERPER_API_KEY
)
for VAR in "${REQUIRED_VARS[@]}"; do
  [[ -n "${!VAR:-}" ]] || error "Required env var '${VAR}' is not set in .env"
done

# Override workspace to local test dir (never touch ~/.openclaw or the VM)
export OPENCLAW_WORKSPACE_ROOT="${TEST_WORKSPACE}"
# Always bind to loopback for local testing regardless of .env setting
export GATEWAY_BIND="loopback"
# For local testing, allowedOrigins only needs localhost
export TAILSCALE_IP="127.0.0.1"
export TAILSCALE_HOSTNAME="localhost"

# ── Install dependencies ──────────────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == false ]]; then
  if ! command -v openclaw >/dev/null 2>&1; then
    log "Installing OpenClaw (npm)…"
    sudo npm install -g openclaw@latest
  else
    log "OpenClaw already installed, skipping."
  fi
else
  log "Skipping installs (--skip-install)."
fi

command -v openclaw >/dev/null 2>&1 || error "openclaw not found after install. Check your PATH."

# ── Set up local test workspace ───────────────────────────────────────────────
log "Setting up test workspace → ${TEST_WORKSPACE}…"
mkdir -p "${TEST_WORKSPACE}"

for AGENT in "${AGENTS[@]}"; do
  SRC="${REPO_DIR}/agents/${AGENT}"
  DEST="${TEST_WORKSPACE}/workspace-${AGENT}"
  mkdir -p "${DEST}/memory" "${DEST}/skills"

  rsync -a --exclude='MEMORY.md' --exclude='memory/' "${SRC}/" "${DEST}/"

  if [[ ! -f "${DEST}/MEMORY.md" ]]; then
    cp "${SRC}/MEMORY.md" "${DEST}/MEMORY.md"
  fi

  ln -sf "${TEST_WORKSPACE}/USER.md" "${DEST}/USER.md"
  log "  ${AGENT}: ready"
done

if [[ ! -f "${TEST_WORKSPACE}/USER.md" ]]; then
  cp "${REPO_DIR}/agents/USER.md" "${TEST_WORKSPACE}/USER.md"
fi

# ── Render openclaw.json ──────────────────────────────────────────────────────
log "Rendering openclaw.json…"
envsubst < "${REPO_DIR}/openclaw.json.template" > "${TEST_WORKSPACE}/openclaw.json"

# ── Cleanup trap ─────────────────────────────────────────────────────────────
OPENCLAW_PID=""
PAPERCLIP_PID=""

cleanup() {
  echo ""
  log "Shutting down…"
  [[ -n "${PAPERCLIP_PID}" ]] && kill "${PAPERCLIP_PID}" 2>/dev/null || true
  [[ -n "${OPENCLAW_PID}" ]] && kill "${OPENCLAW_PID}" 2>/dev/null || true
  wait "${PAPERCLIP_PID}" 2>/dev/null || true
  wait "${OPENCLAW_PID}" 2>/dev/null || true
  log "Stopped. Logs preserved at: ${TEST_WORKSPACE}/"
}
trap cleanup INT TERM EXIT

# ── Start OpenClaw ────────────────────────────────────────────────────────────
log "Starting OpenClaw daemon…"
OPENCLAW_CONFIG_PATH="${TEST_WORKSPACE}/openclaw.json" openclaw gateway run >> "${TEST_WORKSPACE}/openclaw.log" 2>&1 &
OPENCLAW_PID=$!

# Poll: check process is alive for up to 15 seconds
READY=false
for i in $(seq 1 15); do
  if ! kill -0 "${OPENCLAW_PID}" 2>/dev/null; then
    break
  fi
  if grep -q -i "telegram\|ready\|listen\|start" "${TEST_WORKSPACE}/openclaw.log" 2>/dev/null; then
    READY=true; break
  fi
  sleep 1
done

if ! kill -0 "${OPENCLAW_PID}" 2>/dev/null; then
  log "OpenClaw exited immediately. Last log lines:"
  tail -10 "${TEST_WORKSPACE}/openclaw.log" >&2
  error "OpenClaw failed to start. See ${TEST_WORKSPACE}/openclaw.log"
fi
log "OpenClaw is running (PID ${OPENCLAW_PID})."

# Extract gateway auth token written by OpenClaw into the config on first start.
# Give it a moment to write the token if it wasn't already present.
GATEWAY_TOKEN=""
for i in $(seq 1 5); do
  GATEWAY_TOKEN=$(grep -A3 '"auth"' "${TEST_WORKSPACE}/openclaw.json" 2>/dev/null \
    | grep '"token"' | awk -F'"' '{print $4}')
  [[ -n "${GATEWAY_TOKEN}" ]] && break
  sleep 1
done

# ── Start Paperclip (optional) ────────────────────────────────────────────────
if command -v npx >/dev/null 2>&1 && npx paperclipai --version >/dev/null 2>&1; then
  log "Starting Paperclip…"
  npx paperclipai start >> "${TEST_WORKSPACE}/paperclip.log" 2>&1 &
  PAPERCLIP_PID=$!
  sleep 3
  if kill -0 "${PAPERCLIP_PID}" 2>/dev/null; then
    log "Paperclip running (PID ${PAPERCLIP_PID}) → http://localhost:3100"
  else
    log "⚠ Paperclip failed to start. Check ${TEST_WORKSPACE}/paperclip.log"
    PAPERCLIP_PID=""
  fi
else
  log "Paperclip not installed — skipping. Run: npx paperclipai onboard --yes"
fi

# ── Instructions ──────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Personal AI OS — Local Test Running"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Telegram:"
echo "    → @chief_bot (Chief of Staff) / @news_bot (News)"
echo ""
echo "  Paperclip:"
if [[ -n "${PAPERCLIP_PID}" ]]; then
  echo "    → http://localhost:3100"
else
  echo "    → (not running)"
fi
echo ""
echo "  Web Control UI:"
echo "    → http://localhost:18789"
if [[ -n "${GATEWAY_TOKEN}" ]]; then
  echo "    → Gateway token: ${GATEWAY_TOKEN}"
else
  echo "    → Gateway token: (not found — check .test-workspace/openclaw.json → gateway.auth.token)"
fi
echo ""
echo "  Workspace: ${TEST_WORKSPACE}"
echo "  Logs:      ${TEST_WORKSPACE}/openclaw.log"
echo ""
echo "  Press Ctrl+C to stop."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Stream logs ───────────────────────────────────────────────────────────────
tail -f "${TEST_WORKSPACE}/openclaw.log"
