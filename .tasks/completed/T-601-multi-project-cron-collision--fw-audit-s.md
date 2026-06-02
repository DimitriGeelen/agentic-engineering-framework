---
id: T-601
name: "Multi-project cron collision — fw audit schedule install overwrites single /etc/cron.d/agentic-audit, silently disabling all other projects"
description: >
  Inception: Multi-project cron collision — fw audit schedule install overwrites single /etc/cron.d/agentic-audit, silently disabling all other projects

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [urgent]
components: []
related_tasks: []
created: 2026-03-24T09:17:00Z
last_update: 2026-04-12T07:56:40Z
date_finished: 2026-04-12T07:56:40Z
---

# T-601: Multi-project cron collision — fw audit schedule install overwrites single /etc/cron.d/agentic-audit, silently disabling all other projects

## Problem Statement

`fw audit schedule install` writes to hardcoded `/etc/cron.d/agentic-audit`. On multi-project machines, the last project to install silently overwrites all others — disabling scheduled audits for every other project. Same failure class as G-021 (silent enforcement disabling). Discovered 2026-03-24 when 150-skills-manager agent overwrote framework repo's cron without warning.

Research artifact: `docs/reports/T-601-multi-project-cron-collision.md`

## Assumptions

- A-001: Multiple framework-managed projects commonly share a machine (validated: .107 has framework + skills-manager + termlink)
- A-002: `/etc/cron.d/` supports multiple files coexisting (validated: standard cron.d behavior)
- A-003: `basename "$PROJECT_ROOT"` is unique per machine in practice (needs validation)

## Exploration Plan

1. Validate Option D (basename + collision warning) — 15min
2. Check cron.d filename restrictions across Linux distros — 10min
3. Prototype the fix, verify both projects get cron — 20min

## Technical Constraints

- `/etc/cron.d/` filenames: `^[a-zA-Z0-9_-]+$` (no dots, no slashes)
- Requires root/sudo for `/etc/cron.d/` writes
- `schedule remove` and `schedule status` must also be updated

## Scope Fence

**In:** Fix cron filename collision, add overwrite warning, update remove/status
**Out:** Cron content changes, new audit sections, schedule frequency tuning

## Acceptance Criteria

- [x] Problem statement validated
- [x] Options evaluated (see research artifact)
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Option D (basename with collision warning) is clean to implement (<50 lines)
- cron.d filename restrictions don't block project-specific naming

**NO-GO if:**
- cron.d filename restrictions make project-specific naming unreliable across distros
- Multi-project cron creates maintenance burden exceeding the silent-overwrite risk

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Clear bug, clear fix (Option D: basename + collision warning), <50 lines, urgent

## Decisions

**Decision**: GO

**Rationale**: Clear bug, clear fix (Option D: basename + collision warning), <50 lines, urgent

**Date**: 2026-03-24T09:26:11Z
## Decision

**Decision**: GO

**Rationale**: Clear bug, clear fix (Option D: basename + collision warning), <50 lines, urgent

**Date**: 2026-03-24T09:26:11Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-24T09:17:22Z — status-update [task-update-agent]
- **Change:** horizon: now → now
- **Change:** tags: +urgent

### 2026-03-24T09:25:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Clear bug, clear fix (Option D: basename + collision warning), <50 lines, urgent — actively breaking multi-project setups

### 2026-03-24T09:26:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Clear bug, clear fix (Option D: basename + collision warning), <50 lines, urgent

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-06T22:29:32Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-12T07:56:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-12T07:56:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a117633
- **Timestamp:** 2026-06-02T15:03:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
