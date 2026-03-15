# Personal AI OS

A cost-optimized, 6-agent Personal AI Operating System running on a Hetzner CAX11 (ARM64) instance. All agents are accessible through a single Telegram bot — switch between them with `/agent <name>`. Uses OpenRouter's server-side auto routing to pick the most cost-effective model per prompt automatically.

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
       OpenRouter Auto (server-side intelligent routing)
       Picks most cost-effective model per prompt.
       Model pool restricted to Anthropic via OpenRouter
       Plugins dashboard (Sonnet max — no Opus).
            │
            ▼
       OpenRouter (single API key, all models)
```

## Agents & Model Assignment

| Agent | Default Model | Why |
|---|---|---|
| Health | OpenRouter Auto | Mixed complexity — router decides |
| Stocks | OpenRouter Auto | Router picks Sonnet for analysis |
| Portfolio | OpenRouter Auto | Router picks Sonnet for number work |
| News | OpenRouter Auto | Mostly simple summaries → cheap model |
| Jobs | OpenRouter Auto | Mixed — router decides |
| Email | OpenRouter Auto | Mixed — router decides |
| Heartbeats (all) | Free model (pinned) | Zero cost proactive tasks |

OpenRouter's server-side router picks the most cost-effective model per prompt automatically. Model pool is restricted to Anthropic (Haiku/Sonnet only) via the OpenRouter Plugins dashboard.

## Estimated Daily Cost

| Agent | Typical model mix | Est. daily cost (10–20 msgs) |
|---|---|---|
| Health | Haiku / Sonnet mix | ~$0.03 |
| Stocks | Mostly Sonnet | ~$0.12 |
| Portfolio | Mostly Sonnet | ~$0.08 |
| News | Mostly Haiku | ~$0.01 |
| Jobs | Haiku / Sonnet mix | ~$0.03 |
| Email | Haiku / Sonnet mix | ~$0.03 |
| Heartbeats | Free model (pinned) | ~$0.00 |
| **Total** | | **~$0.30/day (~$9/mo)** |

Actual model mix depends on OpenRouter's routing decisions. Check the OpenRouter Activity dashboard to see which model handled each request.

## Prerequisites

| Requirement | Version |
|---|---|
| Node.js | v22+ |
| OpenClaw | latest (`npm install -g openclaw@latest`) |
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

# Install systemd services
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
| `HEARTBEAT_MODEL_ID` | Free model for heartbeat pings (bare OpenRouter model ID, no prefix) |
| `TELEGRAM_BOT_TOKEN` | Your bot token from @BotFather |
| `TELEGRAM_ALLOWED_USER_ID` | Your numeric Telegram user ID (bot ignores everyone else) |
| `OPENCLAW_WORKSPACE_ROOT` | Where agent workspaces live on the VM (default: `/home/clawuser/.openclaw`) |

> **Model routing:** Agent messages use `openrouter/auto`. To restrict which models the router can pick (e.g. Anthropic-only, no Opus), configure defaults in the [OpenRouter Plugins dashboard](https://openrouter.ai/settings/plugins).

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
| **Cost-first routing** | OpenRouter auto router picks cheapest viable model per prompt server-side |
| **GitOps** | No manual edits on VM. Edit locally → push → `./deploy.sh` |
| **Memory safety** | `deploy.sh` never overwrites live `MEMORY.md` files on re-deploy |
| **Context hygiene** | OpenClaw auto-compacts at 8k tokens into daily logs + `MEMORY.md` |
| **Isolated heartbeats** | 55-min timer fires on the cheapest available model per agent |
