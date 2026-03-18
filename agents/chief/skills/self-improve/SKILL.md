# Skill: Self-Improvement Research & Learning Capture

## Two jobs — called separately by two different cron tasks

---

## Job 1 — Proactive scan
Called by the 8:00 PM IST cron ("chief-proactive-scan").
Scan external signals. Generate 0–3 proposals max.

### Sources — ALL calls use exec+curl

**Hacker News Best Stories:**
```
exec: curl -s "https://hacker-news.firebaseio.com/v0/beststories.json"
```
Fetch top 30 IDs then for each:
```
exec: curl -s "https://hacker-news.firebaseio.com/v0/item/<ID>.json"
```
Filter for: AI agents, productivity tools, developer automation, Indian market tools.

**ProductHunt top posts today (skip gracefully if PRODUCTHUNT_API_KEY not set):**
```
exec: curl -s -H "Authorization: Bearer <PRODUCTHUNT_API_KEY>" -H "Content-Type: application/json" -X POST https://api.producthunt.com/v2/api/graphql -d '{"query":"{ posts(first:10,order:VOTES) { nodes { name tagline votesCount url } } }"}'
```

**GitHub Trending RSS:**
```
exec: curl -s "https://mshibanami.github.io/GitHubTrendingRSS/daily/unknown.xml"
```

**Miniflux archive (skip if Phase 1 not deployed):**
```
exec: curl -s -H "X-Auth-Token: <MINIFLUX_API_KEY>" "http://localhost:8080/v1/entries?search=AI+agent&limit=10&published_after=<24h_ago_ISO>"
```

### Evaluation (propose only if 2+ are true)
1. Makes an existing agent meaningfully better
2. Could become a new agent or skill
3. Gap exists for India / personal use
4. Saves time on something currently done manually

### Proposal format — write to FEATURE_REQUESTS.md under 🔵 Proposed
```
* [YYYY-MM-DD] Source: proactive-scan | Priority: P<0-3> | <Title>
  Evidence: <one sentence>
  Change: <plain English — what to add or modify>
  Files: <which agents/files>
  Cost: <zero / +₹X/month>
  Complexity: <Simple / Medium / New agent>
```

Max 3 proposals per run. Do not re-propose anything already in any section.
Empty scan is fine — don't force proposals when signals are weak.

If any proposals added: send Telegram "📋 <n> new idea(s) queued — reply 'review' any time."
If nothing added: HEARTBEAT_OK (no message).

---

## Job 2 — Reactive learning review
Called by the 9:00 PM IST cron ("chief-learning-review").
Collect operational learnings. Promote qualifying entries.

### Step 1: Find all pending .learnings/ entries
```
exec: find $OPENCLAW_WORKSPACE_ROOT -name "ERRORS.md" -path "*/.learnings/*" 2>/dev/null
exec: find $OPENCLAW_WORKSPACE_ROOT -name "LEARNINGS.md" -path "*/.learnings/*" 2>/dev/null
exec: find $OPENCLAW_WORKSPACE_ROOT -name "FEATURE_REQUESTS.md" -path "*/.learnings/*" 2>/dev/null
```
Read each file returned. Identify entries with `**Status:** pending`.

### Step 2: Promotion criteria
Promote to main FEATURE_REQUESTS.md (🔵 Proposed) if ANY of:
- Recurrence ≥ 2
- Priority is `high` or `critical`
- Category is `correction` (always promote — Atharva corrected the agent)

Leave in .learnings/ if:
- Recurrence is 1 AND priority is low/medium AND not a correction

### Step 3: Write promoted entry to FEATURE_REQUESTS.md
```
* [YYYY-MM-DD] Source: operational-learning | Priority: P1 | Fix: <agent> — <summary>
  Evidence: <ERR/LRN/FEAT ID> in workspace-<agent>/.learnings/<file>.md
  Change: Update <HEARTBEAT.md / SOUL.md / AGENTS.md> to handle this correctly
  Files: agents/<agent>/<specific file>
  Cost: zero
  Complexity: Simple
```

### Step 4: Mark source entries as promoted
Update each promoted entry's Status from `pending` → `promoted` in its source file.

### Step 5: Consolidate in-session feature requests
For each agent's .learnings/FEATURE_REQUESTS.md with pending entries:
- Add to main FEATURE_REQUESTS.md under 🔵 Proposed
- Update source entry Status to `promoted`

### Promotion targets by type
| Type | File to recommend changing |
|---|---|
| Exec call consistently fails | HEARTBEAT.md (fix the command) |
| Agent misunderstands its role | SOUL.md |
| Workflow or delegation wrong | AGENTS.md |
| Tool usage mistake | HEARTBEAT.md (add explicit note) |
| User corrected agent behaviour | SOUL.md or HEARTBEAT.md |
| API/external service changed | Relevant SKILL.md |

If any entries were promoted: send Telegram "🔁 <n> operational learning(s) promoted to review queue."
If nothing to promote: HEARTBEAT_OK (no message).
