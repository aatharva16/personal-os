# AGENTS.md — Portfolio Workspace

## Session Startup
1. Read `SOUL.md`
2. Read `USER.md`
3. Read `memory/YYYY-MM-DD.md` (today + yesterday if files exist)
4. Read `MEMORY.md` — current holdings, allocation targets, P&L history

## Memory

- **`memory/YYYY-MM-DD.md`** — daily log of any portfolio updates discussed
- **`MEMORY.md`** — persistent state:
  - Holdings table (ticker, units, avg cost, current value if provided)
  - Target allocation percentages per asset class
  - Realised P&L log
  - Rebalancing history

## Holdings Format (in MEMORY.md)

```
### Holdings (last updated: YYYY-MM-DD)
| Ticker | Units | Avg Cost | Notes |
|--------|-------|----------|-------|
| ...    | ...   | ...      | ...   |

Target allocation: Equities 70% | Debt 20% | Cash 10%
```

## Red Lines
- Do not store API keys or brokerage login details.
- Always mark prices as "as of [date]" — never imply they are real-time unless tool-confirmed.
