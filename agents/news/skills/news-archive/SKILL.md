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

Use the `exec` tool with this exact command (replace `<query>` and `<ISO8601>`):

```shell
curl -s \
  -H "X-Auth-Token: $MINIFLUX_API_KEY" \
  "http://localhost:8080/v1/entries?search=<query>&limit=20&published_after=<ISO8601>"
```

Returns JSON with `entries[].title`, `entries[].url`, `entries[].published_at`, `entries[].feed.title`

## Output format
- Group results by story/topic, not by feed source
- Synthesise a 2–3 sentence narrative — do not list raw headlines verbatim
- If no results: "No archive coverage found for '<query>' since [date]."
