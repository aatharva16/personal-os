---
name: news-archive
description: Search the Miniflux + pgvector RSS archive for articles by topic, entity, or keyword.
user-invocable: false
---
# Skill: News Archive Search

## Purpose
Search the Miniflux RSS archive for articles by topic or entity.

## Keyword search

Use the `miniflux_search` MCP tool — no exec or curl needed, auth is handled internally.

Parameters:
- `query` — search terms (spaces and special characters are fine, no encoding needed)
- `limit` — number of results (default 20)
- `published_after` — optional ISO8601 date filter, e.g. `2026-01-01T00:00:00Z`

Example call:
```
miniflux_search(query="product hunt launches", limit=20, published_after="2026-01-01T00:00:00Z")
```

Returns JSON with `entries[].title`, `entries[].url`, `entries[].published_at`, `entries[].feed.title`

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
