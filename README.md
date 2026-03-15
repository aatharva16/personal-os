# Personal AI OS

A cost-optimized, multi-agent Personal AI Operating System running on a Hetzner CAX11 (ARM64) instance. Three specialized agents — health, stocks, and email — each accessible via their own Telegram bot, all powered by a NadirClaw model router that intelligently routes prompts between cheap and premium LLMs.

## Architecture

```
Telegram (@health_bot, @stocks_bot, @email_bot)
            │
            ▼
    OpenClaw Gateway daemon          ← openclaw.json config
    (ws://localhost:18789)
            │
            ▼
  Agent workspaces (per agent):
    ~/.openclaw/workspace-<name>/
      SOUL.md    ← immutable personality
      MEMORY.md  ← long-term persistent knowledge
      AGENTS.md  ← session startup instructions
      USER.md    ← shared user profile (symlink)
      memory/    ← daily session logs
            │
            ▼
    NadirClaw Proxy (localhost:8856)  ← nadirclaw.service
    sentence-embedding classifier (~10ms)
            │
      ┌─────┴──────┐
      ▼            ▼
  Simple prompt  Complex prompt
  Gemini Flash   Claude 3.5 Sonnet
  (cheap)        (smart)
            │
            ▼
       OpenRouter / Anthropic API
```

## Prerequisites

| Requirement | Version |
|---|---|
| Node.js | v22+ |
| Python | 3.10+ |
| OpenClaw | latest (`npm install -g openclaw@latest`) |
| NadirClaw | latest (`pip install nadirclaw`) |
| Telegram bots | 3 bots from @BotFather (one per agent) |

## Quickstart (Local)

```bash
git clone <your-private-repo> personal-os
cd personal-os
cp .env.example .env
# Edit .env — fill in API keys and Telegram bot tokens

# Install
npm install -g openclaw@latest
pip install nadirclaw

# Start NadirClaw router
nadirclaw serve &

# Render openclaw.json and start the gateway
source .env
mkdir -p ~/.openclaw
envsubst < openclaw.json.template > ~/.openclaw/openclaw.json

# Sync agent workspaces to ~/.openclaw/
for agent in health stocks email; do
  rsync -a agents/$agent/ ~/.openclaw/workspace-$agent/
  ln -sf ~/.openclaw/USER.md ~/.openclaw/workspace-$agent/USER.md
done
cp agents/USER.md ~/.openclaw/USER.md

openclaw daemon --config ~/.openclaw/openclaw.json
```

## VM Deployment (Hetzner CAX11)

### One-time setup

```bash
# On the VM as clawuser
git clone <your-private-repo> ~/personal-os
cd ~/personal-os
cp .env.example .env && nano .env

# Install systemd services
sudo cp systemd/nadirclaw.service /etc/systemd/system/
sudo cp systemd/personal-os.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nadirclaw
sudo systemctl enable --now personal-os
sudo systemctl enable --now personal-os-heartbeat.timer
```

### GitOps deployments (after initial setup)

```bash
./deploy.sh               # pull latest, sync workspaces, restart
./deploy.sh --branch dev  # deploy a specific branch
```

### Logs

```bash
journalctl -u personal-os -f        # OpenClaw daemon
journalctl -u nadirclaw -f          # NadirClaw router
journalctl -u personal-os-heartbeat # Heartbeat runs
```

## Adding a New Agent

1. Create `agents/<name>/SOUL.md` — write the personality (narrative style, first person)
2. Create `agents/<name>/MEMORY.md` — initial empty memory
3. Create `agents/<name>/AGENTS.md` — session startup instructions
4. Create a new Telegram bot via @BotFather
5. Add the bot token to `.env` as `TELEGRAM_BOT_TOKEN_<NAME>`
6. Add the agent entry and binding to `openclaw.json.template`
7. Run `./deploy.sh`

## Configuration Reference

### .env variables

| Variable | Description |
|---|---|
| `NADIRCLAW_SIMPLE_MODEL` | Model for simple prompts (e.g. `google/gemini-flash-1.5-8b`) |
| `NADIRCLAW_COMPLEX_MODEL` | Model for complex prompts (e.g. `anthropic/claude-3.5-sonnet`) |
| `NADIRCLAW_CONFIDENCE_THRESHOLD` | Routing threshold (default `0.06`) |
| `NADIRCLAW_PORT` | NadirClaw port (default `8856`) |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENROUTER_API_KEY` | OpenRouter API key (for multi-provider routing) |
| `TELEGRAM_BOT_TOKEN_HEALTH` | Telegram token for Vita (health bot) |
| `TELEGRAM_BOT_TOKEN_STOCKS` | Telegram token for Quant (stocks bot) |
| `TELEGRAM_BOT_TOKEN_EMAIL` | Telegram token for Hermes (email bot) |
| `TELEGRAM_ALLOWED_USER_ID` | Your numeric Telegram ID (only you can message the bots) |
| `OPENCLAW_WORKSPACE_ROOT` | Where agent workspaces live on the VM |

## Design Principles

| Pillar | Implementation |
|---|---|
| **Modular Agents** | Each agent is a folder with `SOUL.md` + `MEMORY.md` + `AGENTS.md`. Add one by adding a folder. |
| **GitOps Workflow** | No manual edits on the VM. Edit locally → push → `./deploy.sh`. |
| **Memory Hygiene** | OpenClaw's `memoryFlush` compacts context at 8,000 tokens into daily logs and `MEMORY.md`. |
| **Isolated Heartbeats** | 55-minute systemd timer triggers `openclaw heartbeat --all` using the cheap model. |
