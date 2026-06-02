---
id: T-806
name: "fw doctor token health — show session token usage in health check"
description: >
  Add token usage line to fw doctor output. Show current session tokens and cache hit rate as an informational line. Quick integration using lib/costs.sh.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [tokens, doctor, observability]
components: [bin/fw]
related_tasks: []
created: 2026-04-03T19:42:49Z
last_update: 2026-04-12T07:55:19Z
date_finished: 2026-04-12T07:55:19Z
---

# T-806: fw doctor token health — show session token usage in health check

## Context

Extends `fw doctor` with token health info line. Uses `fw costs current` parsing from lib/costs.sh (T-801).

## Acceptance Criteria

### Agent
- [x] `fw doctor` output includes a token usage informational line
- [x] Shows current session total tokens and turns
- [x] Graceful: if no JSONL transcript found, line is omitted

## Verification

bin/fw doctor 2>&1 | grep -qi "token"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-03T19:42:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-806-fw-doctor-token-health--show-session-tok.md
- **Context:** Initial task creation

### 2026-04-12T07:55:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f04b1405
- **Timestamp:** 2026-06-02T15:04:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw doctor 2>&1 | grep -qi "token"`
