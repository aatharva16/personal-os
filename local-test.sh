#!/usr/bin/env bash
# =============================================================================
# local-test.sh — Personal AI OS Local E2E Test
#
# Starts NadirClaw + OpenClaw on your local machine (no systemd, no VM).
# Your Telegram bot will respond to messages in real time.
#
# Prerequisites:
#   - .env file populated with real OPENROUTER_API_KEY, TELEGRAM_BOT_TOKEN,
#     TELEGRAM_ALLOWED_USER_ID (copy .env.example and fill in values)
#   - Node.js v22+, Python 3, pip3, envsubst (apt install gettext-base)
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

AGENTS=(health stocks portfolio news jobs email)

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
command -v python3  >/dev/null 2>&1 || error "Python 3 is not installed."
command -v pip3     >/dev/null 2>&1 || error "pip3 is not installed."
command -v envsubst >/dev/null 2>&1 || error "envsubst not found. Run: sudo apt install gettext-base"

NODE_VERSION=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
(( NODE_VERSION >= NODE_MIN_VERSION )) || \
  error "Node.js v${NODE_MIN_VERSION}+ required (found v${NODE_VERSION})."

[[ -f "${REPO_DIR}/.env" ]] || \
  error ".env not found. Run: cp .env.example .env  then fill in OPENROUTER_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USER_ID"

# Load and validate env vars
set -a; source "${REPO_DIR}/.env"; set +a

REQUIRED_VARS=(
  NADIRCLAW_PORT
  NADIRCLAW_SIMPLE_MODEL
  NADIRCLAW_COMPLEX_MODEL
  OPENROUTER_API_KEY
  TELEGRAM_BOT_TOKEN
  TELEGRAM_ALLOWED_USER_ID
)
for VAR in "${REQUIRED_VARS[@]}"; do
  [[ -n "${!VAR:-}" ]] || error "Required env var '${VAR}' is not set in .env"
done

# Override workspace to local test dir (never touch ~/.openclaw or the VM)
export OPENCLAW_WORKSPACE_ROOT="${TEST_WORKSPACE}"

# ── Install dependencies ──────────────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == false ]]; then
  log "Installing OpenClaw (npm)…"
  npm install -g openclaw@latest

  log "Installing NadirClaw (pip)…"
  pip3 install --upgrade nadirclaw
else
  log "Skipping installs (--skip-install)."
fi

command -v openclaw  >/dev/null 2>&1 || error "openclaw not found after install. Check your PATH."
command -v nadirclaw >/dev/null 2>&1 || error "nadirclaw not found after install. Check your PATH."

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
NADIRCLAW_PID=""
OPENCLAW_PID=""

cleanup() {
  echo ""
  log "Shutting down…"
  [[ -n "${NADIRCLAW_PID}" ]] && kill "${NADIRCLAW_PID}" 2>/dev/null || true
  [[ -n "${OPENCLAW_PID}"  ]] && kill "${OPENCLAW_PID}"  2>/dev/null || true
  wait "${NADIRCLAW_PID}" "${OPENCLAW_PID}" 2>/dev/null || true
  log "Stopped. Logs preserved at:"
  log "  ${TEST_WORKSPACE}/nadirclaw.log"
  log "  ${TEST_WORKSPACE}/openclaw.log"
}
trap cleanup INT TERM EXIT

# ── Start NadirClaw ───────────────────────────────────────────────────────────
log "Starting NadirClaw on port ${NADIRCLAW_PORT}…"
nadirclaw serve >> "${TEST_WORKSPACE}/nadirclaw.log" 2>&1 &
NADIRCLAW_PID=$!

# Poll for readiness (max 20 seconds)
READY=false
for i in $(seq 1 20); do
  if curl -sf "http://localhost:${NADIRCLAW_PORT}/health" >/dev/null 2>&1; then
    READY=true; break
  fi
  sleep 1
done
if [[ "${READY}" == false ]]; then
  log "NadirClaw did not start in time. Last log lines:"
  tail -5 "${TEST_WORKSPACE}/nadirclaw.log" >&2
  error "NadirClaw failed to start. See ${TEST_WORKSPACE}/nadirclaw.log"
fi
log "NadirClaw is up."

# ── Start OpenClaw ────────────────────────────────────────────────────────────
log "Starting OpenClaw daemon…"
openclaw daemon --config "${TEST_WORKSPACE}/openclaw.json" >> "${TEST_WORKSPACE}/openclaw.log" 2>&1 &
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

# ── Instructions ──────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Personal AI OS — Local Test Running"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Open Telegram and message your bot:"
echo ""
echo "    > Hello                 ← talks to Vita (Health)"
echo "    > /agent stocks         ← switch to Quant (Stocks)"
echo "    > /agent email          ← switch to Hermes (Email)"
echo "    > /agent portfolio      ← switch to Portfolio"
echo "    > /new                  ← reset the session"
echo ""
echo "  Workspace: ${TEST_WORKSPACE}"
echo ""
echo "  Press Ctrl+C to stop."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Stream logs ───────────────────────────────────────────────────────────────
tail -f "${TEST_WORKSPACE}/openclaw.log" "${TEST_WORKSPACE}/nadirclaw.log"
