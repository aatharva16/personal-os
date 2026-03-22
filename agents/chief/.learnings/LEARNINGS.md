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
**Summary:** Paperclip onboarding must run inline — never spawn threaded sessions
**Detail:** Paperclip's onboarding instructions tell the agent to spawn a "paperclip-onboarding" session with thread=true, but OpenClaw does not support threaded subagent sessions. This causes an infinite retry loop. The correct approach is to handle all onboarding steps (reachability test, join request, key exchange) inline in the current session.
**Promote to:** SOUL.md (done)
**Recurrence:** 0
