# Heartbeat Tasks — Chief of Staff

Fires every 30 min within activeHours (06:30–22:00 IST). This heartbeat does ONE thing: check open delegations.

Morning briefing → dedicated cron at 7:30 AM IST
Proactive scan  → dedicated cron at 8:00 PM IST
Learning review → dedicated cron at 9:00 PM IST

---

## Delegations audit (every heartbeat)

1. Read MEMORY.md → Active Delegations section
   (MEMORY.md IS auto-loaded — no explicit read needed)
2. If any delegation > 24 hours unresolved → send Telegram flag
3. Write: `[HEARTBEAT] Delegations: <n open / none>`

---

## Error capture

If anything went wrong in this heartbeat (exec error, user correction):

Exec failure → write to .learnings/ERRORS.md:
```
## [ERR-<YYYYMMDD>-<3 chars>]
**Logged:** <ISO timestamp> | **Priority:** high | **Status:** pending
**Agent:** chief
**Summary:** <one line — what failed>
**Error:** <exact error text>
**Context:** <what was being attempted>
**Recurrence:** 1
```

User correction → write to .learnings/LEARNINGS.md:
```
## [LRN-<YYYYMMDD>-<3 chars>] correction
**Logged:** <ISO timestamp> | **Priority:** high | **Status:** pending
**Agent:** chief
**Category:** correction
**Summary:** <what was wrong>
**Detail:** <what Atharva said and what the correct approach is>
**Promote to:** SOUL.md / HEARTBEAT.md / AGENTS.md
**Recurrence:** 1
```
