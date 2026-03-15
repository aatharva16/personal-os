# Personal AI OS

A cost-optimized, 6-agent Personal AI Operating System running on a Hetzner CAX11 (ARM64) instance. All agents are accessible through a single Telegram bot — switch between them with `/agent <name>`. Powered by NadirClaw's automatic cheap/smart model routing via OpenRouter.

**Expected monthly LLM cost at moderate daily use: ~$5–15** (vs $50–150+ without cost optimization)

## Architecture

```
Telegram (single bot — /agent <id> to switch)
            │
            ▼
    OpenClaw Gateway (localhost:18789)     ← ~/.openclaw/openclaw.json
            │
            ├── /agent health    → workspace-health/
            ├── /agent stocks    → workspace-stocks/
            ├── /agent portfolio → workspace-portfolio/
            ├── /agent news      → workspace-news/
            ├── /agent jobs      → workspace-jobs/
            └── /agent email     → workspace-email/
                    │
                    ▼ (each workspace has)
              SOUL.md    ← personality (short — every char costs tokens)
              MEMORY.md  ← long-term knowledge (grows over time)
              AGENTS.md  ← session startup procedure
              USER.md    ← shared user profile (symlinked)
              memory/    ← daily session logs (YYYY-MM-DD.md)
                    │
                    ▼
    NadirClaw Proxy (localhost:8856)        ← nadirclaw.service
    sentence-embedding classifier (~10ms overhead)
            │
      ┌─────┴──────┐
      ▼            ▼
  Simple prompt  Complex prompt
  Gemini Flash   Claude Sonnet
  ~$0.07/M tok   ~$3/M tok
            │
            ▼
       OpenRouter (single API key, all models)
```

## Agents & Model Assignment

| Agent | Default Model | Why |
|---|---|---|
| Health | NadirClaw auto | Mixed complexity — NadirClaw decides |
| Stocks | NadirClaw auto | NadirClaw routes analysis to Sonnet |
| Portfolio | NadirClaw auto | NadirClaw routes number work to Sonnet |
| News | NadirClaw auto | Mostly simple summaries → Gemini Flash |
| Jobs | NadirClaw auto | Mixed — NadirClaw decides |
| Email | NadirClaw auto | Mixed — NadirClaw decides |
| Heartbeats (all) | Gemini Flash 8B | Cheap proactive tasks |

NadirClaw's classifier pushes ~60–70% of prompts to the cheap model automatically, without any manual routing decisions.

## Estimated Daily Cost

| Agent | Typical model hit | Est. daily cost (10–20 msgs) |
|---|---|---|
| Health | 70% Flash / 30% Sonnet | ~$0.03 |
| Stocks | 40% Flash / 60% Sonnet | ~$0.12 |
| Portfolio | 40% Flash / 60% Sonnet | ~$0.08 |
| News | 90% Flash / 10% Sonnet | ~$0.01 |
| Jobs | 70% Flash / 30% Sonnet | ~$0.03 |
| Email | 70% Flash / 30% Sonnet | ~$0.03 |
| Heartbeats | Gemini Flash 8B | ~$0.01 |
| **Total** | | **~$0.31/day (~$9/mo)** |

## Prerequisites

| Requirement | Version |
|---|---|
| Node.js | v22+ |
| Python | 3.10+ |
| OpenClaw | latest (`npm install -g openclaw@latest`) |
| NadirClaw | latest (`pip install nadirclaw`) |
| OpenRouter account | One API key for all models — openrouter.ai |
| Telegram bot | One bot from @BotFather |

## Quickstart (Local Dev)

```bash
git clone <your-private-repo> personal-os
cd personal-os
cp .env.example .env
# Edit .env — fill in OPENROUTER_API_KEY and TELEGRAM_BOT_TOKEN

# Install
npm install -g openclaw@latest
pip install nadirclaw

# Start NadirClaw
source .env && nadirclaw serve &

# Sync workspaces and render config
mkdir -p ~/.openclaw
for agent in health stocks portfolio news jobs email; do
  rsync -a agents/$agent/ ~/.openclaw/workspace-$agent/
  mkdir -p ~/.openclaw/workspace-$agent/memory ~/.openclaw/workspace-$agent/skills
  ln -sf ~/.openclaw/USER.md ~/.openclaw/workspace-$agent/USER.md
done
cp agents/USER.md ~/.openclaw/USER.md
envsubst < openclaw.json.template > ~/.openclaw/openclaw.json

openclaw daemon --config ~/.openclaw/openclaw.json
```

## VM Deployment (Hetzner CAX11)

### One-time setup

```bash
# On the VM as clawuser
git clone <your-private-repo> ~/personal-os
cd ~/personal-os
cp .env.example .env && nano .env   # fill in secrets

# Install system deps
sudo apt install -y gettext-base    # for envsubst

# Install runtimes
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g openclaw@latest
pip3 install nadirclaw

# Install systemd services
sudo cp systemd/nadirclaw.service /etc/systemd/system/
sudo cp systemd/personal-os.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.timer /etc/systemd/system/
sudo systemctl daemon-reload

# First deploy (installs, syncs workspaces, starts services)
./deploy.sh
```

### Subsequent deploys (GitOps)

```bash
# On the VM
./deploy.sh               # pull latest, sync, restart
./deploy.sh --skip-install  # skip npm/pip install (faster)
```

### Logs

```bash
journalctl -u personal-os -f        # OpenClaw gateway
journalctl -u nadirclaw -f          # NadirClaw router
journalctl -u personal-os-heartbeat # Heartbeat runs
```

## Using the Bots

In Telegram, message your bot:

```
/agent health    → talk to Health Tracker (default)
/agent stocks    → Stock Analyser
/agent portfolio → Portfolio Checker
/agent news      → News Feed
/agent jobs      → Job Searcher
/agent email     → Email Organiser
/new             → reset session context (keeps memory, clears conversation)
/context list    → inspect token usage before a heavy task
```

## Configuration Reference

### .env variables

| Variable | Description |
|---|---|
| `OPENROUTER_API_KEY` | OpenRouter API key — one key for all models |
| `NADIRCLAW_SIMPLE_MODEL` | Cheap model for simple prompts (default: `openrouter/google/gemini-flash-1.5-8b`) |
| `NADIRCLAW_COMPLEX_MODEL` | Smart model for complex prompts (default: `openrouter/anthropic/claude-sonnet-4-5`) |
| `NADIRCLAW_CONFIDENCE_THRESHOLD` | Routing sensitivity (default: `0.06`, lower = more complex routing) |
| `NADIRCLAW_PORT` | NadirClaw port (default: `8856`) |
| `TELEGRAM_BOT_TOKEN` | Your bot token from @BotFather |
| `TELEGRAM_ALLOWED_USER_ID` | Your numeric Telegram user ID (bot ignores everyone else) |
| `OPENCLAW_WORKSPACE_ROOT` | Where agent workspaces live on the VM (default: `/home/clawuser/.openclaw`) |

## Adding an Agent

1. Create `agents/<name>/SOUL.md` — keep it under 200 words (every char is a token)
2. Create `agents/<name>/MEMORY.md` — initial empty state
3. Create `agents/<name>/AGENTS.md` — session startup instructions
4. Add the agent entry to `openclaw.json.template` under `agents.list`
5. Run `./deploy.sh`

## Design Principles

| Pillar | Implementation |
|---|---|
| **Single interface** | One Telegram bot, `/agent <id>` routing — no app switching |
| **Cost-first routing** | NadirClaw classifies every prompt; ~65% hit cheap models automatically |
| **GitOps** | No manual edits on VM. Edit locally → push → `./deploy.sh` |
| **Memory safety** | `deploy.sh` never overwrites live `MEMORY.md` files on re-deploy |
| **Context hygiene** | OpenClaw auto-compacts at 8k tokens into daily logs + `MEMORY.md` |
| **Isolated heartbeats** | 55-min timer fires on the cheapest available model per agent |
