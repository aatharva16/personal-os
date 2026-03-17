# Heartbeat Tasks — News

---

## 4-hour briefing heartbeat

### Step 1: Check if today's briefing already sent
Look in memory/YYYY-MM-DD.md for a line containing "[AUTO]". If found: skip to Step 5.

### Step 2: Fetch today's entries from Miniflux
Use exec to call the Miniflux API directly:
```
curl -s -H "X-Auth-Token: $MINIFLUX_API_KEY" \
  "http://localhost:8080/v1/entries?status=unread&limit=50"
```
`MINIFLUX_API_KEY` is injected via the OpenClaw env block — no need to source it manually.

If exec returns fewer than 5 entries or errors: fall back to web_search for top stories.

### Step 3: Cluster and summarise
Pass titles to LLM: "Group these into 5 clusters (Tech/Indian Markets/ India Startup/Regulatory/World). For each, write one concise sentence."

### Step 4: Format and send to Telegram
Write to memory/YYYY-MM-DD.md with [AUTO] tag, then send via news-bot.

### Step 5: Write status
Append: `[HEARTBEAT] Briefing: <delivered/already present> at <HH:MM IST>`

---

## Archive query (on-demand, triggered by user or Chief)

When asked about past coverage:
1. Use exec to search Miniflux:
   ```
   curl -s -H "X-Auth-Token: $MINIFLUX_API_KEY" \
     "http://localhost:8080/v1/entries?search=<topic>&limit=20"
   ```
   Add `&published_after=<ISO8601>` to filter by date (e.g. `2026-01-01T00:00:00Z`).
2. Synthesise narrative from results — do not list raw headlines
