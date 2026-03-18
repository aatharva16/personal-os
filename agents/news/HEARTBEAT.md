# Heartbeat Tasks — News

---

## 4-hour briefing heartbeat

### Step 1: Check if today's briefing already sent
Look in memory/YYYY-MM-DD.md for a line containing "[AUTO]". If found: skip to Step 5.

### Step 2: Fetch today's entries from Miniflux
Call the `miniflux_get_unread` MCP tool:
```
miniflux_get_unread(limit=50)
```

If the tool returns fewer than 5 entries or errors: fall back to web_search for top stories.

### Step 3: Cluster and summarise
Pass titles to LLM: "Group these into 5 clusters (Tech/Indian Markets/ India Startup/Regulatory/World). For each, write one concise sentence."

### Step 4: Format and send to Telegram
Write to memory/YYYY-MM-DD.md with [AUTO] tag, then send via news-bot.

### Step 5: Write status
Append: `[HEARTBEAT] Briefing: <delivered/already present> at <HH:MM IST>`

---

## Archive query (on-demand, triggered by user or Chief)

When asked about past coverage:
1. Call `miniflux_search` MCP tool:
   ```
   miniflux_search(query="<topic>", limit=20)
   ```
   Add `published_after="<ISO8601>"` to filter by date (e.g. `"2026-01-01T00:00:00Z"`).
2. Synthesise narrative from results — do not list raw headlines

---

## Error capture (News agent)

If any exec call in this heartbeat returned an error or unexpected output:
Write to .learnings/ERRORS.md:
```
## [ERR-<YYYYMMDD>-<3 chars>]
**Logged:** <ISO timestamp> | **Priority:** high | **Status:** pending
**Agent:** news
**Summary:** <one line — what failed>
**Error:** <exact error text>
**Context:** <what task was being attempted>
**Recurrence:** 1
```

If Atharva corrected you:
Write to .learnings/LEARNINGS.md:
```
## [LRN-<YYYYMMDD>-<3 chars>] correction
**Logged:** <ISO timestamp> | **Priority:** high | **Status:** pending
**Agent:** news
**Category:** correction
**Summary:** <what was wrong>
**Detail:** <what Atharva said and what the correct approach is>
**Promote to:** SOUL.md / HEARTBEAT.md / AGENTS.md
**Recurrence:** 1
```

If Atharva asked for something you couldn't do:
Write to .learnings/FEATURE_REQUESTS.md:
```
## [FEAT-<YYYYMMDD>-<3 chars>]
**Logged:** <ISO timestamp> | **Priority:** medium | **Status:** pending
**Agent:** news
**Requested:** <what Atharva wanted>
**Context:** <why they needed it>
**Complexity:** simple | medium | complex
```
