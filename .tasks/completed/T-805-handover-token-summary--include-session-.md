---
id: T-805
name: "Handover token summary — include session token usage in handover documents"
description: >
  Add current session token usage summary to the handover document. When fw handover runs, include: total tokens consumed, turns, cache hit rate, and avg tokens/turn. Uses fw costs current data. Enables tracking token consumption per-session in the handover trail.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [tokens, handover, observability]
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-04-03T19:23:46Z
last_update: 2026-04-12T07:55:16Z
date_finished: 2026-04-12T07:55:16Z
---

# T-805: Handover token summary — include session token usage in handover documents

## Context

Follow-up from T-801. Handover documents track session state — adding token usage makes token consumption visible across sessions. Uses `fw costs current` parsing.

## Acceptance Criteria

### Agent
- [x] `handover.sh` includes a "Token Usage" section in the generated handover
- [x] Section shows: total tokens, turns, cache hit rate
- [x] Graceful degradation: if no JSONL transcript found, section is omitted
- [x] Handover YAML frontmatter includes `token_usage` field
- [x] Verify handover includes token data (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "token_usage\|Token Usage" agents/handover/handover.sh
grep -q "token" agents/handover/handover.sh

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

### 2026-04-03T19:23:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-805-handover-token-summary--include-session-.md
- **Context:** Initial task creation

### 2026-04-12T07:55:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
