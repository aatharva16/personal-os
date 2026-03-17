---
name: news-archive
description: Search the Miniflux + pgvector RSS archive for articles by topic, entity, or keyword.
user-invocable: false
requires:
  env: [MINIFLUX_API_KEY]
---
# Skill: News Archive Search

## Purpose
Search the Miniflux + pgvector archive for articles by topic or entity.

## IMPORTANT: exec+curl only — web_fetch will not work
`web_fetch` cannot reach `localhost:8080` with custom headers. Every Miniflux call MUST go through the `exec` tool running `curl`.

## MANDATORY: Authentication header
Every curl call MUST include `-H "X-Auth-Token: $MINIFLUX_API_KEY"`.
Omitting it will always return `{"error_message":"access unauthorized"}`.
`$MINIFLUX_API_KEY` is provided by the runtime via `requires.env` — never hardcode a value.

WRONG:   `-H "X-Auth-Token: '$MINIFLUX_API_KEY'"`  ← single quotes inside double quotes send the literal string `'key'`
CORRECT: `-H "X-Auth-Token: $MINIFLUX_API_KEY"`    ← no single quotes; shell expands the variable correctly

## Keyword search

Use the `exec` tool with this exact command. Use `-G --data-urlencode` so curl percent-encodes
spaces and special characters in the query automatically — do NOT embed the query directly in the
URL path, as unencoded spaces cause `curl exit code 3` (URL malformed).

Replace `<query>` with the search terms and `<ISO8601>` with the date (e.g. `2026-01-01T00:00:00Z`):

```shell
curl -s -G \
  -H "X-Auth-Token: $MINIFLUX_API_KEY" \
  --data-urlencode "search=<query>" \
  --data-urlencode "published_after=<ISO8601>" \
  "http://localhost:8080/v1/entries?limit=20"
```

Returns JSON with `entries[].title`, `entries[].url`, `entries[].published_at`, `entries[].feed.title`

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
