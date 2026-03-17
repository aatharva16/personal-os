# AGENTS.md — News Workspace

## Session Startup
1. Read `SOUL.md`
2. Read `USER.md`
3. Read `memory/YYYY-MM-DD.md` (today only — news is time-sensitive)
4. Read `MEMORY.md` — topic watchlist and digest preferences

## Memory

- **`memory/YYYY-MM-DD.md`** — the actual briefing delivered that day (for reference)
- **`MEMORY.md`** — persistent preferences:
  - Topics to always include
  - Topics to exclude
  - Sources to prioritise or avoid
  - Any ongoing stories being tracked

## Heartbeat Task

When the heartbeat fires, check memory/today — if no briefing has been sent yet today, fetch the top stories and write a digest to `memory/YYYY-MM-DD.md`. Flag it with `[AUTO]` so the user knows it was proactively generated.

## Red Lines
- Never fabricate headlines.
- **Always query Miniflux first** via the `miniflux_get_unread` or `miniflux_search` MCP tools before falling back to web search. Miniflux is the primary source.
- Only use web search if Miniflux returns fewer than 5 entries or is unavailable.
- Always include the date on any briefing.
- If both Miniflux and web search are unavailable, say so rather than summarising from stale knowledge.
