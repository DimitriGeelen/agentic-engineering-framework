---
id: T-629
name: "Framework self-governance failures — ultra-deep audit of operational friction, deadlocks, and self-defeating enforcement"
description: >
  The framework's own governance is actively blocking real work. This session hit: stale global scripts deadlocking all tools, task gates blocking memory writes, inception gates blocking commits, hooks failing on missing scripts, long commands breaking in terminals. 12-agent TermLink investigation into every operational friction point, deadlock pattern, and self-defeating enforcement.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [bin/fw, web/blueprints/docs.py, web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: []
created: 2026-03-26T21:35:09Z
last_update: 2026-03-27T10:22:30Z
date_finished: 2026-03-27T09:56:27Z
---

# T-629: Framework self-governance failures — ultra-deep audit of operational friction, deadlocks, and self-defeating enforcement

## Problem Statement

The framework's own governance is actively blocking real work. Session 2026-03-26 evidence: stale global scripts caused total deadlock 3x, task gate blocked memory writes, inception gate blocked commits, missing hook scripts caused cascading failures, long commands broke terminal paste 3x. 12 TermLink agents investigated every friction point. Core finding: **27% real work, 73% overhead** (governance friction + meta-work + housekeeping).

## Assumptions

- A1: Hook fail-open (missing script → exit 0) won't create security gaps (**Confirmed** — hooks are agent-discipline, not security boundaries)
- A2: FW_SAFE_MODE env var is accessible to hook scripts at runtime (**Confirmed** — bash inherits env)
- A3: CLAUDE.md can be cut to <400 lines without losing structural enforcement (**Confirmed** — 13 behavioral rules have zero enforcement, TermLink/dispatch protocol can move to docs/)
- A4: Inception commit limit of 2 is too restrictive (**Confirmed** — 24+ bypasses recorded, concern R-032 since Feb 19)
- A5: Proactive health check as PostToolUse hook won't add significant overhead (**Untested** — run every 50 calls, fast checks)

## Exploration Plan

12 TermLink agents dispatched, all completed. See `docs/reports/T-629-governance-self-audit.md` for consolidated findings and `docs/reports/fw-agent-t629-{01..12}-*.md` for full reports (3109 lines).

## Technical Constraints

- Claude Code hooks snapshot at session start — settings.json changes require restart
- PreToolUse exit 0 = allow, exit 2 = block. PostToolUse is advisory only.
- CLAUDE.md is loaded every session regardless of size (no conditional loading mechanism currently)
- Hook scripts must exist and be executable when registered — missing scripts cause non-zero exit → block

## Scope Fence

**IN scope:** 4-phase governance fix (emergency → pruning → self-healing → architecture)
**OUT of scope:** Rewriting Claude Code hook system, changing PreToolUse/PostToolUse semantics

## Acceptance Criteria

### Agent
- [x] Problem statement validated (3x deadlocks, 3x terminal failures, 27% real work ratio)
- [x] 12-agent investigation completed (3109 lines of findings)
- [x] 5 structural flaws identified with evidence
- [x] 4-phase fix plan proposed with go/no-go criteria
- [x] Research artifact committed: `docs/reports/T-629-governance-self-audit.md`
- [x] 12 agent reports preserved: `docs/reports/fw-agent-t629-{01..12}-*.md`

### Human
- [x] [REVIEW] Review 4-phase governance fix and approve go/no-go
  **Steps:**
  1. Read `docs/reports/T-629-governance-self-audit.md`
  2. Evaluate: is 27% real work acceptable? Are the 5 structural flaws accurate?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-629 go --rationale "your rationale"`
  **Expected:** GO decision, Phase 1 emergency fixes built next
  **If not:** Specify which phase to defer or reject

## Go/No-Go Criteria

**GO if:**
- Phase 1 (safe mode + fail-open + exempt paths) can be built in one session
- CLAUDE.md can be cut to <400 lines without losing structural enforcement
- 27% real work is unacceptable and the 4-phase plan addresses the root causes

**NO-GO if:**
- Governance overhead is acceptable for the project's maturity stage
- Cutting rules would reintroduce problems they were created to prevent
- 90% meta-work ratio is temporary (project is in framework-building phase)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 12-agent audit confirmed 5 structural flaws, 27% real work unacceptable

**Date**: 2026-03-27T09:37:28Z
## Decision

**Decision**: GO

**Rationale**: 12-agent audit confirmed 5 structural flaws, 27% real work unacceptable

**Date**: 2026-03-27T09:37:28Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T09:37:28Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 12-agent audit confirmed 5 structural flaws, 27% real work unacceptable

### 2026-03-27T09:56:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-41bd7363
- **Timestamp:** 2026-06-02T15:03:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
