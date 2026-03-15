#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Personal AI OS GitOps Deployment Script
#
# Run this on the Hetzner VM (as clawuser) to pull the latest changes from
# GitHub, validate the configuration, and restart the systemd service.
#
# Usage:
#   ./deploy.sh [--branch <branch>] [--skip-install]
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="personal-os"
BRANCH="${BRANCH:-main}"
NODE_MIN_VERSION=22

# ── Parse args ────────────────────────────────────────────────────────────────
SKIP_INSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --skip-install) SKIP_INSTALL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() { echo "[deploy] $*"; }
error() { echo "[deploy] ERROR: $*" >&2; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
log "Running pre-flight checks…"

command -v node >/dev/null 2>&1 || error "Node.js is not installed."
command -v git  >/dev/null 2>&1 || error "git is not installed."

NODE_VERSION=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
if (( NODE_VERSION < NODE_MIN_VERSION )); then
  error "Node.js v${NODE_MIN_VERSION}+ required. Found v${NODE_VERSION}."
fi

[[ -f "${REPO_DIR}/.env" ]] || error ".env file not found. Copy .env.example and fill in secrets."

# ── Validate required env vars ────────────────────────────────────────────────
log "Validating .env…"
source "${REPO_DIR}/.env"

REQUIRED_VARS=(OPENROUTER_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USER_ID)
for VAR in "${REQUIRED_VARS[@]}"; do
  [[ -n "${!VAR:-}" ]] || error "Required env var '${VAR}' is not set in .env"
done

# ── Pull latest code ──────────────────────────────────────────────────────────
log "Fetching latest code from origin/${BRANCH}…"
cd "${REPO_DIR}"
git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git reset --hard "origin/${BRANCH}"

log "Now at commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty='%s')"

# ── Install / update dependencies ─────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == false ]]; then
  log "Installing npm dependencies…"
  npm ci --omit=dev
else
  log "Skipping npm install (--skip-install flag set)."
fi

# ── Restart systemd service ───────────────────────────────────────────────────
log "Restarting systemd service '${SERVICE_NAME}'…"
if systemctl is-active --quiet "${SERVICE_NAME}"; then
  sudo systemctl restart "${SERVICE_NAME}"
else
  sudo systemctl start "${SERVICE_NAME}"
fi

sudo systemctl enable "${SERVICE_NAME}" 2>/dev/null || true

sleep 2
if systemctl is-active --quiet "${SERVICE_NAME}"; then
  log "✓ Service '${SERVICE_NAME}' is running."
else
  error "Service '${SERVICE_NAME}' failed to start. Check: journalctl -u ${SERVICE_NAME} -n 50"
fi

log "Deployment complete."
