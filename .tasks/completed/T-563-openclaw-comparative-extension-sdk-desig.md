---
id: T-563
name: "OpenClaw comparative: extension SDK design — what enables 80+ extensions"
description: >
  Dispatch to OpenClaw eval agent: What makes 80+ extensions possible? Minimal surface area for a working extension? Extension isolation (one bad extension doesnt crash system)? Contributor DX? Is there a pattern for making our framework extensible by other projects? Write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:17:44Z
last_update: 2026-03-28T09:32:09Z
date_finished: 2026-03-28T09:32:09Z
---

# T-563: OpenClaw comparative: extension SDK design — what enables 80+ extensions

## Problem Statement

Compare OpenClaw's extension SDK (80+ extensions) vs our agent/hook model. See `docs/reports/T-563-extension-sdk-design.md`.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (NO-GO — governance, not extensibility)

## Go/No-Go Criteria

**GO if:** Need community extensions. **NO-GO if:** Extensions should be governed (validated).

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T19:26:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:32:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
