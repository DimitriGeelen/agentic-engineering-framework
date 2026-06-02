---
id: T-866
name: "Audit cron zombie accumulation — flock guard, timeout, stale reaper"
description: >
  Inception: Audit cron zombie accumulation — flock guard, timeout, stale reaper

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T20:43:13Z
last_update: 2026-04-13T06:23:29Z
date_finished: 2026-04-05T05:39:21Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-866: Audit cron zombie accumulation — flock guard, timeout, stale reaper

## Problem Statement

136 `fw audit` processes accumulated over 41 days uptime, consuming all CPU (load 158) and forcing 22GB swap thrashing. Root cause: 4 cron files in /etc/cron.d/ schedule ~32 audit invocations per cycle across 4 projects. Audit processes get stuck (>90s runtime with 100+ tasks) and pile up because there is no: (1) singleton guard, (2) execution timeout, (3) stale process reaper.

**Evidence:** User RCA on 2026-04-04. Immediate fix: cron files removed. Structural fix needed in audit.sh.

**Related:** T-862 (pre-push fast audit — partially addresses runtime), T-860 (audit performance inception).

## Assumptions

- A1: `flock` is available on all target platforms (Linux, macOS via brew)
- A2: A 5-minute timeout is sufficient for the heaviest audit section
- A3: Per-project lock files prevent cross-project interference
- A4: Cron invocations with `--cron` flag should be the only ones guarded (manual runs are interactive)

## Exploration Plan

1. **Spike A**: Add flock-based singleton guard to audit.sh --cron mode
2. **Spike B**: Add timeout wrapper (5 min default, configurable via FW_AUDIT_TIMEOUT)
3. **Spike C**: Add stale process detection in cron retention section
4. **Evaluate**: Test with simulated concurrent runs

## Technical Constraints

- Must work on Linux (primary) and macOS (flock availability varies)
- Must not interfere with manual `fw audit` runs (only guard --cron)
- Lock files should be per-project to allow parallel audits across different projects

## Scope Fence

**IN scope:** flock guard, timeout wrapper, stale process reaper for audit.sh
**OUT of scope:** Audit performance optimization (T-860), cron schedule changes

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- flock or equivalent available on Linux (primary platform)
- Timeout + guard can be added without breaking existing audit functionality

**NO-GO if:**
- Platform compat issues make singleton guard unreliable
- Fix requires rewriting audit.sh architecture (defer to T-860)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: flock guard, timeout, stale reaper all feasible on Linux with macOS fallback

**Date**: 2026-04-05T05:39:21Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** All three mechanisms are feasible, well-scoped, and address the root cause. flock is available on Linux. macOS fallback identified. Changes are confined to --cron mode entry point (~50 lines), zero impact on manual audit runs.
- **Evidence:**
  - flock available at `/usr/bin/flock` ✓
  - 18+ zombie processes confirmed running right now ✓
  - Lock directory `.context/locks/` already exists ✓
  - FW_AUDIT_TIMEOUT follows existing `FW_*` config pattern ✓
  - All changes in first 50 lines of audit.sh, cron-only path ✓
- **Research artifact:** `docs/reports/T-866-audit-cron-zombies.md`

## Decision

**Decision**: GO

**Rationale**: flock guard, timeout, stale reaper all feasible on Linux with macOS fallback

**Date**: 2026-04-05T05:39:21Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T21:49:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-05T05:39:21Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** flock guard, timeout, stale reaper all feasible on Linux with macOS fallback

### 2026-04-05T05:39:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8be4474
- **Timestamp:** 2026-06-02T15:05:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
