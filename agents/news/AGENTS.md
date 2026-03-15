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
- Never fabricate headlines. Use web search for all news content.
- Always include the date on any briefing.
- If web search is unavailable, say so rather than summarising from stale knowledge.
