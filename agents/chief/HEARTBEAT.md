# Heartbeat Tasks — Chief of Staff

Run these checks on every heartbeat. Keep actions brief. Write a single status line to `memory/YYYY-MM-DD.md` at the end.

---

1. **Open delegations audit**
   - Read `MEMORY.md` → check Active Delegations section
   - If any delegation is older than 24 hours and still unresolved → send the user a Telegram message flagging it

2. **Write status**
   - Append one line to `memory/YYYY-MM-DD.md`:
     ```
     [HEARTBEAT] <brief status, e.g. "No open delegations.">
     ```
