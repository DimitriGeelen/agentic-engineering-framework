---
id: T-860
name: "Audit performance — 123 active tasks × 7 loops × 15 Python calls = >90s runtime"
description: >
  Audit performance — 123 active tasks × 7 loops × 15 Python calls = >90s runtime

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T19:33:13Z
last_update: 2026-04-13T06:23:28Z
date_finished: 2026-04-06T11:45:34Z
---

# T-860: Audit performance — 123 active tasks × 7 loops × 15 Python calls = >90s runtime

## Problem Statement

`fw audit` takes 3m56s (measured). Cron runs every 15 minutes — a 4-minute audit blocks other cron jobs. Root cause: 10 separate loops over task files (132 active + 740 completed), each spawning multiple subprocesses (grep, sed, head). `sys` time (4m8s) exceeds real time — confirms subprocess fork/exec overhead is dominant.

**For whom:** Framework cron system and any user running `fw audit` manually.
**Why now:** 132 active tasks growing. Previous measurement was 90s — now at 236s (2.6× worse).

## Assumptions

- A-1: Subprocess spawning is the primary bottleneck (confirmed by sys > real)
- A-2: Merging loops will reduce iterations from 3802 to ~1000
- A-3: A `--fast` flag for cron can skip completed-task analysis safely
- A-4: The audit's 10-loop structure is accidental, not by design

## Exploration Plan

1. Measured audit runtime: 3m56s ✓
2. Inventoried loops: 10 loops, 3802 total iterations ✓
3. Profiled bottleneck: subprocess spawning (sys 4m8s) ✓
4. Evaluated 4 optimization options ✓

## Technical Constraints

- `audit.sh` is 3274 lines — rewriting is substantial
- Cron audit uses flock + timeout (T-866) — audit must finish within timeout
- Some checks require Python (YAML parsing, pattern matching)
- Task file format is stable (Markdown with YAML frontmatter)

## Scope Fence

**IN:** Reduce audit runtime to <60s for standard run, <30s for `--fast`
**OUT:** Rewriting audit in Python (Phase 3, separate task if needed)

## Acceptance Criteria

### Agent
- [x] Problem statement validated — 3m56s measured, 10 loops identified
- [x] Assumptions tested — subprocess spawning confirmed as dominant cost
- [x] Recommendation written with rationale (GO — Phase 1: --fast flag, Phase 2: merge loops)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-860-audit-performance.md`
  2. Evaluate: is the phased approach (fast flag + loop merge) acceptable?
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-860 go --rationale "your rationale"`
  **Expected:** Decision recorded, build tasks created
  **If not:** Ask for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Audit runtime is measurably reduced (target: <60s standard, <30s fast)
- `--fast` flag is safe for cron (no critical checks skipped)
- Loop merge is incremental (can be done one pair at a time)

**NO-GO if:**
- The audit structure is too complex to merge safely
- Fast mode would miss critical compliance issues

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Loop merge first, not --fast. Value analysis confirms expensive loops catch real issues.

**Date**: 2026-04-06T11:45:34Z

## Recommendation

- **Recommendation:** GO (revised: loop merge first, NOT --fast flag)
- **Rationale:** Value analysis of 50 audit snapshots shows the expensive loops (completed-task checks) are the ones that actually catch real issues — 6+ warnings acted on. A `--fast` flag skipping them would remove the audit's most valuable checks. The right fix is making iterations cheaper (merge loops, reduce subprocess spawning), not removing them. Phase 1: merge 10 loops into 3 passes. Phase 2: fix noisy Loop 2 thresholds.
- **Evidence:**
  - 3m56s measured (reproducible), was 90s when task was created — 2.6× degradation
  - `sys 4m8s` confirms subprocess fork/exec is the bottleneck
  - 10 loops × avg 380 iterations = 3802 total, each spawning 2-5 subprocesses
  - Cron runs every 15 min — 4-minute audit leaves only 11 minutes between audits
  - **Value data:** Loops 3/4/5/7 (completed + inception checks) produced warnings acted on 6+ times. Loop 2 (quality) produced warnings that persisted weeks without action — noise, not signal

## Decision

**Decision**: GO

**Rationale**: Loop merge first, not --fast. Value analysis confirms expensive loops catch real issues.

**Date**: 2026-04-06T11:45:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T19:34:28Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-05T12:16:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now

### 2026-04-06T11:45:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Loop merge first, not --fast. Value analysis confirms expensive loops catch real issues.

### 2026-04-06T11:45:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next
