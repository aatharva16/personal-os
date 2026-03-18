# Skill: Generate Implementation Plan

## Purpose
When user approves a feature proposal in the daily debate, generate a Claude Code-ready implementation plan file.

## Trigger
User approves a proposal (replies 'yes' during debate session).

## Output location
Save to: `memory/plans/YYYY-MM-DD-<feature-slug>.md`
(Create `memory/plans/` if it doesn't exist)

## Plan format

```markdown
# Implementation Plan: <Feature Name>
**Generated:** YYYY-MM-DD | **Approved:** YYYY-MM-DD
**Source:** [ID from FEATURE_REQUESTS.md]
**Complexity:** Simple / Medium / New agent

---

## Context
<Why this matters. One paragraph. Reference the proposal evidence.>

## What to build
<Plain English. No jargon.>

## Files to CREATE
- **Path:** `exact/path/from/repo/root`
  **Content:**
  ```
  <full content — no placeholders, no TODOs>
  ```

## Files to MODIFY
- **Path:** `exact/path/from/repo/root`
  **Section:** exact heading
  **Replace:**
  ```
  <exact current text>
  ```
  **With:**
  ```
  <exact new text>
  ```

## Step-by-step for Claude Code
1. <specific action>
2. <specific action>

## Verification
- [ ] <how to test>
- [ ] <expected output>

## Constraints — do NOT change
- <what to leave alone>

## Cost impact
<estimate or "zero">
```

## After writing
1. Move item from 🔵 Proposed → ✅ Approved in FEATURE_REQUESTS.md
2. Add plan path to the approved entry
3. Tell user: "Plan at memory/plans/<filename> — ready for Claude Code."
