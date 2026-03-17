---
name: news-archive
description: Search the Miniflux RSS archive for articles by topic, entity, or keyword.
user-invocable: false
---
# Skill: News Archive Search

## Purpose
Search the Miniflux RSS archive for articles by topic or entity.

## Keyword search

Call the `miniflux_search` MCP tool:

```
miniflux_search(query="<topic>", limit=20)
```

To filter by date, pass `published_after`:
```
miniflux_search(query="product hunt launches", limit=20, published_after="2026-01-01T00:00:00Z")
```

To list all subscribed feeds:
```
miniflux_get_feeds()
```

Returns JSON with `entries[].title`, `entries[].url`, `entries[].published_at`, `entries[].feed.title`

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
