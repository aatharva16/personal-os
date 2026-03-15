# Personal AI OS

A cost-optimized personal AI operating system built on [OpenClaw](https://docs.openclaw.ai). A **Chief of Staff** bot handles all coordination via Telegram and delegates specialist work to dedicated agents. Each agent also has its own Telegram bot for direct access.

Uses OpenRouter's server-side auto routing to pick the most cost-effective model per prompt automatically. Heartbeats are pinned to a free model (zero cost). Runs on a Hetzner VM; Web Control UI is accessible via Tailscale VPN.

## Architecture

```
Telegram: @chief_bot  ───→  Chief of Staff
                                │  sessions_spawn/send
                                └──→  News agent

Telegram: @news_bot   ───→  News agent (direct)

Browser (Tailscale)   ───→  http://<tailscale-ip>:18790  (Web Control UI)
[local]               ───→  http://localhost:18790

                   OpenClaw Gateway
                          │
                   OpenRouter API
              ┌────────────┴──────────────┐
         Agent tasks                 Heartbeats
         (openrouter/auto)           (free model, pinned)
```

## Agents

| Agent | Bot | Role |
|---|---|---|
| **Chief of Staff** | `@chief_bot` | Primary coordinator — routes tasks to specialists, handles general requests directly |
| **News** | `@news_bot` | Daily briefings (tech, Indian markets, geopolitics), story tracking |

*More specialists will be added as the suite grows. Each new agent requires only a new workspace directory + config entry — no code changes.*

## Prerequisites

| Requirement | Version / Source |
|---|---|
| Node.js | v22+ |
| OpenClaw | latest (`npm install -g openclaw@latest`) |
| OpenRouter account | One API key — [openrouter.ai](https://openrouter.ai) |
| Telegram bots | 2 bots from [@BotFather](https://t.me/BotFather) |

## Quickstart (Local Dev)

```bash
git clone <your-repo> personal-os && cd personal-os

cp .env.example .env
# Fill in:
#   OPENROUTER_API_KEY
#   HEARTBEAT_MODEL_ID
#   TELEGRAM_BOT_TOKEN_CHIEF
#   TELEGRAM_BOT_TOKEN_NEWS
#   TELEGRAM_ALLOWED_USER_ID
#   WEBCHAT_PORT=18790
#   WEBCHAT_TOKEN=$(openssl rand -hex 32)

./local-test.sh
# Prints the WebChat URL + token at startup.
# Press Ctrl+C to stop.
```

## VM Deployment (Hetzner)

### One-time setup

```bash
# On the VM as clawuser
git clone <your-repo> ~/personal-os
cd ~/personal-os
cp .env.example .env && nano .env   # fill in all secrets

# System deps
sudo apt install -y gettext-base nodejs    # Node v22+ required

# Install OpenClaw
npm install -g openclaw@latest

# Install systemd services
sudo cp systemd/personal-os.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.service /etc/systemd/system/
sudo cp systemd/personal-os-heartbeat.timer /etc/systemd/system/
sudo systemctl daemon-reload

# Tailscale (one-time, for Web Control UI access)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# On your device: install Tailscale app and log in with the same account.
# Optional firewall hardening:
#   sudo ufw allow in on tailscale0 to any port 18790
#   sudo ufw deny 18790

# First deploy
./deploy.sh
# Prints Tailscale IP and WebChat token at the end.
```

### Subsequent deploys (GitOps)

```bash
./deploy.sh               # pull latest, sync workspaces, restart
./deploy.sh --skip-install  # skip npm install (faster if no version change)
```

### Logs

```bash
journalctl -u personal-os -f        # live gateway logs
journalctl -u personal-os-heartbeat # heartbeat run history
```

## Web Control UI

The Web Control UI lets you see all agent sessions and memory state in a browser.

| Environment | URL |
|---|---|
| Local | `http://localhost:18790` |
| Production | `http://<tailscale-ip>:18790` |

Enter the `WEBCHAT_TOKEN` from your `.env` when prompted. The token is also printed by both `local-test.sh` and `deploy.sh` for easy copy-paste.

## Configuration Reference

| Variable | Description |
|---|---|
| `OPENROUTER_API_KEY` | OpenRouter API key |
| `HEARTBEAT_MODEL_ID` | Free OpenRouter model ID for heartbeats (no prefix) |
| `TELEGRAM_BOT_TOKEN_CHIEF` | Chief of Staff bot token (from @BotFather) |
| `TELEGRAM_BOT_TOKEN_NEWS` | News bot token (from @BotFather) |
| `TELEGRAM_ALLOWED_USER_ID` | Your numeric Telegram user ID (bot ignores everyone else) |
| `WEBCHAT_PORT` | Port for Web Control UI (default: 18790) |
| `WEBCHAT_TOKEN` | Auth token for Web Control UI |
| `OPENCLAW_WORKSPACE_ROOT` | Where agent workspaces live on the VM |

> **Model routing:** Agent messages use `openrouter/auto`. To restrict the model pool (e.g. Anthropic-only, no Opus), configure defaults in the [OpenRouter Plugins dashboard](https://openrouter.ai/settings/plugins).

## Adding a New Agent

1. Create `agents/<name>/SOUL.md` — personality and role (keep it concise)
2. Create `agents/<name>/MEMORY.md` — initial empty state
3. Create `agents/<name>/AGENTS.md` — session startup instructions
4. Create `agents/<name>/HEARTBEAT.md` — proactive tasks for the 55-min timer
5. Add the agent to `openclaw.json.template` under `agents.list`
6. Add a new bot token env var and entry to `channels.telegram.bots` in the template
7. Add a binding in `bindings` mapping the new bot to the new agent
8. Add the new agent ID to `AGENTS=(...)` in both `deploy.sh` and `local-test.sh`
9. Update the agent registry in `agents/chief/AGENTS.md`
10. Run `./deploy.sh`

## Design Principles

| Pillar | Implementation |
|---|---|
| **Chief of Staff as entry point** | Single coordinator bot handles all requests; delegates to specialists |
| **One bot per agent** | Direct access to any specialist without routing through Chief |
| **Cost-first routing** | OpenRouter auto router picks cheapest viable model per prompt server-side |
| **Free heartbeats** | Hardcoded free model for all heartbeats; bypasses auto router entirely |
| **Reliable heartbeats** | Native OpenClaw heartbeat disabled (known multi-agent bug); uses systemd timer + HEARTBEAT.md instead |
| **GitOps** | No manual edits on VM — edit locally → push → `./deploy.sh` |
| **Memory safety** | `deploy.sh` never overwrites live `MEMORY.md` or `memory/` on re-deploy |
| **Context hygiene** | OpenClaw auto-compacts at 8k tokens into daily logs + `MEMORY.md` |
| **Secure UI access** | Web Control UI on dedicated port, Tailscale VPN for production access |
