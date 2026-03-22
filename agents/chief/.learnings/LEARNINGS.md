# Operational Learnings Log

_Corrections from Atharva, knowledge gaps, better approaches discovered._
_Chief's 9 PM cron promotes corrections and recurring items._

<!-- Entry format:
## [LRN-YYYYMMDD-XXX] category
**Logged:** ISO timestamp | **Priority:** high/medium/low | **Status:** pending
**Agent:** chief
**Category:** correction | knowledge_gap | best_practice
**Summary:** one line
**Detail:** what was wrong, what Atharva said, what the correct approach is
**Promote to:** SOUL.md / HEARTBEAT.md / AGENTS.md / TOOLS.md
**Recurrence:** 1
-->

## [LRN-20260322-001] best_practice
**Logged:** 2026-03-22T18:55:00+05:30 | **Priority:** high | **Status:** promoted
**Agent:** chief
**Category:** best_practice
**Summary:** Paperclip onboarding — never use thread=true (use inline or regular sessions_spawn)
**Detail:** Paperclip's onboarding instructions tell the agent to spawn a session with thread=true, but OpenClaw does not support threaded sessions. This causes an infinite retry loop. The correct approach is to either handle onboarding inline or use a regular sessions_spawn (without thread=true).
**Promote to:** SOUL.md (done)
**Recurrence:** 0
