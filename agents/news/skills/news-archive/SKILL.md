---
name: news-archive
description: Search the Miniflux RSS archive for articles by topic, entity, or keyword.
user-invocable: false
---
# Skill: News Archive Search

## Purpose
Search the Miniflux RSS archive for articles by topic or entity.

## Keyword search

Use exec to call the Miniflux search API directly. `MINIFLUX_API_KEY` is injected
via the OpenClaw env block — no need to source it manually.

```
curl -s -H "X-Auth-Token: $MINIFLUX_API_KEY" \
  "http://localhost:8080/v1/entries?search=<query>&limit=20"
```

To filter by date, append `&published_after=<ISO8601>`, e.g.:
```
curl -s -H "X-Auth-Token: $MINIFLUX_API_KEY" \
  "http://localhost:8080/v1/entries?search=product+hunt+launches&limit=20&published_after=2026-01-01T00:00:00Z"
```

Note: URL-encode spaces as `+` or `%20` in the query string.

Returns JSON with `entries[].title`, `entries[].url`, `entries[].published_at`, `entries[].feed.title`

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
