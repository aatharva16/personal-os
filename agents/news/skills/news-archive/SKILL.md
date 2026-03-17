# Skill: News Archive Search

## Purpose
Search the Miniflux + pgvector archive for articles by topic or entity.

## IMPORTANT: All Miniflux calls use exec+curl
The web_fetch tool cannot call localhost:8080 with custom headers. Use exec with curl for ALL Miniflux API calls.

## Keyword search
```
exec: curl -s -H "X-Auth-Token: <MINIFLUX_API_KEY from environment>" "http://localhost:8080/v1/entries?search=<query>&limit=20&published_after=<ISO8601>"
```
Returns JSON with entries[].title, entries[].url, entries[].published_at, entries[].feed.title

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
