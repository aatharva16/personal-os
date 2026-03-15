# Personal AI OS

A cost-optimized, multi-agent Personal AI Operating System running on a Hetzner CAX11 (ARM64) instance, controlled via Telegram.

## Architecture

```
Telegram Bot
     │
     ▼
  src/index.js          ← Unified interface, slash-command routing
     │
     ▼
src/agents/<name>/      ← Modular agents (health, stocks, email, …)
  SOUL.md               ← Immutable personality & constraints
  MEMORY.md             ← Persistent knowledge (auto-updated)
     │
     ▼
src/router/nadir.js     ← NadirClaw: intelligent model router
     │
     ├── Low complexity  → MODEL_CHEAP  (Gemini Flash 1.5-8B)
     └── High complexity → MODEL_SMART  (Claude 3.5 Sonnet)
          │
          ▼
     OpenRouter API      ← Single endpoint for all upstream models
```

## Quickstart

### 1. Local setup

```bash
# Requires Node.js v22+
git clone <your-private-repo> personal-os
cd personal-os
cp .env.example .env
# Edit .env with your OpenRouter API key and Telegram bot token
npm install
npm start
```

### 2. Telegram commands

| Command | Description |
|---|---|
| `/start` | Welcome message |
| `/agent <name>` | Switch active agent |
| `/reset` | Clear session history |
| `/memory` | View agent's persistent memory |
| `/status` | System info |
| `/help` | Command reference |

Available agents: `health`, `stocks`, `email`

## Adding a new agent

1. Create the folder: `src/agents/<name>/`
2. Add `SOUL.md` (personality, capabilities, hard limits)
3. Add `MEMORY.md` (initial state, typically empty)
4. Register in `src/agents/index.js`

## Configuration

All settings live in `.env` (copy from `.env.example`):

| Variable | Description | Default |
|---|---|---|
| `OPENROUTER_API_KEY` | OpenRouter API key | required |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | required |
| `TELEGRAM_ALLOWED_USER_ID` | Your Telegram user ID | required |
| `NADIR_COMPLEXITY_THRESHOLD` | Score (0–100) above which Claude 3.5 Sonnet is used | `60` |
| `MODEL_CHEAP` | Model for simple tasks | `google/gemini-flash-1.5-8b` |
| `MODEL_SMART` | Model for complex tasks | `anthropic/claude-3.5-sonnet` |
| `MEMORY_COMPACTION_THRESHOLD` | Token count triggering auto-compaction | `8000` |

## VM Deployment (Hetzner CAX11)

### One-time setup

```bash
# On the VM, as clawuser
git clone <your-private-repo> ~/personal-os
cd ~/personal-os
cp .env.example .env && nano .env   # fill in secrets

# Install systemd services
sudo cp systemd/personal-os.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now personal-os
sudo systemctl enable --now personal-os-heartbeat.timer
```

### GitOps deployments

```bash
# On the VM — pull latest and restart
./deploy.sh

# Override branch
./deploy.sh --branch my-feature
```

### Logs

```bash
journalctl -u personal-os -f           # Bot logs
journalctl -u personal-os-heartbeat -f # Heartbeat logs
```

## Design Principles

| Pillar | Implementation |
|---|---|
| **Modular Agents** | Each agent has its own `SOUL.md` + `MEMORY.md`. Add agents by adding a folder. |
| **GitOps Workflow** | No manual edits on the VM. Push to GitHub → run `deploy.sh`. |
| **Memory Hygiene** | Auto-compaction at 8,000 tokens keeps context predictable and costs low. |
| **Isolated Heartbeats** | Agents run background tasks every 55 min using the cheap model. |
