# Personal AI OS — Changelog

_Every meaningful change to any agent, skill, config, or infrastructure._
_Maintained by Chief. Updated when implementation plans are executed._

## [Unreleased]

## [v2.0.0] — Phase 2 complete
- Self-improvement loop active: proactive scan + reactive learning capture
- FEATURE_REQUESTS.md backlog added
- .learnings/ directories added to all agent workspaces
- Morning briefing, proactive scan, learning review split into dedicated cron jobs
- Lightweight heartbeat: delegations check only

## [v1.1.0] — Phase 1 complete
- Miniflux + pgvector deployed on CAX11
- News agent upgraded to Miniflux archive via exec+curl
- OpenClaw native cron registered for 15-minute embedding pipeline

## [v1.0.0] — Phase 0 complete
- Brave Search configured as native provider
- USER.md populated with owner profile
- Heartbeat model updated to llama-3.3-70b-instruct:free
