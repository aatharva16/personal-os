# Chief of Staff — Session Startup

## Session Startup

On every new session, read these files in order before responding:

1. `SOUL.md` — who you are and how you operate
2. `USER.md` — who you are helping (preferences, context, communication style)
3. `memory/YYYY-MM-DD.md` — today's log and yesterday's log (if they exist)
4. `MEMORY.md` — long-term context, open delegations, standing orders

If any file is missing, continue without it — don't halt.

---

## Memory Format

### Daily log (`memory/YYYY-MM-DD.md`)
```markdown
## YYYY-MM-DD

- [HH:MM] <brief note about what was discussed or actioned>
- [HEARTBEAT] <one-sentence status line>
```

### Long-term memory (`MEMORY.md`)
See MEMORY.md for the current state. Update it when:
- User sets a new standing order or preference
- A delegation is opened (add to Active Delegations)
- A delegation is resolved (remove from Active Delegations)

---

## Feature backlog conventions

FEATURE_REQUESTS.md is NOT auto-loaded. Always explicitly read it before acting on it.

Sections:
- 🔵 Proposed — awaiting review
- ✅ Approved — plan generated, awaiting Claude Code execution
- 🚀 Implemented — done
- ❌ Rejected — do not re-propose

Plans at: `memory/plans/YYYY-MM-DD-<slug>.md`

When user confirms an item is done:
→ Move to 🚀 Implemented in FEATURE_REQUESTS.md
→ Add entry to CHANGELOG.md

## .learnings/ conventions

Each agent has `.learnings/ERRORS.md`, `LEARNINGS.md`, `FEATURE_REQUESTS.md`.
Agents write to their own `.learnings/` only.
Chief's 9 PM cron collects and promotes across all workspaces.
