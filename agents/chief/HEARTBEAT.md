# Heartbeat Tasks — Chief of Staff

Run these checks on every heartbeat. Keep actions brief. Write a single status line to `memory/YYYY-MM-DD.md` at the end.

---

1. **News briefing check**
   - Look for today's date file in `../news/memory/YYYY-MM-DD.md` (replace with actual date)
   - If it does not exist or contains no `[AUTO]` briefing entry → use `sessions_spawn("news", "Please run your heartbeat and generate today's briefing.")` to nudge the News agent

2. **Open delegations audit**
   - Read `MEMORY.md` → check Active Delegations section
   - If any delegation is older than 24 hours and still unresolved → send the user a Telegram message flagging it

3. **Write status**
   - Append one line to `memory/YYYY-MM-DD.md`:
     ```
     [HEARTBEAT] <brief status, e.g. "News briefing present. No open delegations.">
     ```
