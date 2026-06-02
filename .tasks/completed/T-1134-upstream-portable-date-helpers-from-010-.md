---
id: T-1134
name: "Upstream portable date helpers from 010-termlink — lib/compat.sh _date_to_epoch + episodic verification"
description: >
  Upstream portable date helpers from 010-termlink — lib/compat.sh _date_to_epoch + episodic verification

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T09:12:20Z
last_update: 2026-04-13T06:23:19Z
date_finished: 2026-04-12T11:03:33Z
---

# T-1134: Upstream portable date helpers from 010-termlink — lib/compat.sh _date_to_epoch + episodic verification

## Problem Statement

010-termlink independently developed two patches addressing framework portability issues:
1. **Portable date helpers** (`_date_to_epoch`, `_days_ago_epoch` in lib/compat.sh) replacing GNU-only `date -d` with a GNU→BSD→python3 fallback chain. Affects: episodic.sh, checkpoint.sh, metrics.sh.
2. **Episodic verification** in update-task.sh: post-generation check that .context/episodic/T-XXX.yaml exists, with WARNING + manual recovery command if missing.

Framework currently has 3 files using `date -d` (GNU-only) which silently fail on macOS. T-1133 (from ring20-manager pickup) independently reported the same issue.

## Assumptions

- A1: `date -d` calls in framework fail on macOS (CONFIRMED — BSD date uses different flags)
- A2: lib/compat.sh is the right place for portable helpers (CONFIRMED — already has compat functions)
- A3: Episodic verification catches silent generation failures (CONFIRMED — T-1132 pickup reports same gap)
- A4: Patches from 010-termlink are compatible with upstream framework (needs code review)

## Exploration Plan

1. Identify all `date -d` calls in framework (DONE — 3 files: checkpoint.sh, episodic.sh, metrics.sh)
2. Review proposed fallback chain (GNU→BSD→python3) for correctness
3. Evaluate episodic verification approach
4. Recommend GO/NO-GO

## Scope Fence

**IN:** Evaluate and upstream the two patches from 010-termlink.
**OUT:** Implementing — separate build task after GO.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- `date -d` calls confirmed to fail on macOS (CONFIRMED — 3 files affected)
- Fallback chain is sound (GNU→BSD→python3 covers all platforms)
- lib/compat.sh already exists as the portability layer
- Two independent reports confirm the issues (T-1132, T-1133 pickups from ring20-manager)

**NO-GO if:**
- Fallback chain has edge cases that produce incorrect results
- Changes break existing behavior on Linux (primary platform)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Three framework files use GNU-only `date -d` which fails on macOS. The compat.sh fallback chain (GNU→BSD→python3) is the standard pattern for this project's portability directive (D-004). Episodic verification catches a real gap (T-1132 confirms). Both patches come from 010-termlink's production use and are ready to upstream with code review.

**Evidence:**
- 3 files use `date -d`: agents/context/checkpoint.sh, agents/context/lib/episodic.sh, metrics.sh
- lib/compat.sh already exists as the portability layer (has shell detection, path resolution)
- Two independent cross-project reports: T-1132 (episodic verification gap) and T-1133 (date portability)
- D-004 (Portability directive) explicitly requires cross-platform support
- 010-termlink verified the patches on Linux; macOS testing needed as part of build

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Three framework files use GNU-only `date -d` which fails on macOS. The compat.sh fallback chain (GNU→BSD→python3) is the standard pattern for this project's portabili...

**Date**: 2026-04-12T11:03:33Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Three framework files use GNU-only `date -d` which fails on macOS. The compat.sh fallback chain (GNU→BSD→python3) is the standard pattern for this project's portabili...

**Date**: 2026-04-12T11:03:33Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T11:03:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Three framework files use GNU-only `date -d` which fails on macOS. The compat.sh fallback chain (GNU→BSD→python3) is the standard pattern for this project's portabili...

### 2026-04-12T11:03:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-830cb5d8
- **Timestamp:** 2026-06-02T14:55:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
