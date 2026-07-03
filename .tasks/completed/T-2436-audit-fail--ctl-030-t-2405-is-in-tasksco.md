---
id: T-2436
name: "Audit FAIL — CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expe..."
description: >
  Audit FAIL — CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expe...

status: work-completed
workflow_type: build
audit_severity: fail
audit_finding_hash: 3761940e5769451cd7c1df080b155478c1096260
tags: [audit-finding, severity:fail, section:CTL-030]
owner: agent
horizon: null
tags: []
components: [C-004, bin/fw]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-02T18:35:18Z
last_update: 2026-07-03T22:46:54Z
date_finished: 2026-07-03T22:46:54Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2436: Audit FAIL — CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expe...
## Trigger

Audit run: 2026-07-02T18:35:18Z
Finding: CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)

## Finding

```
CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)
```

Mitigation: Fix: bin/migrate-horizon-null-completed.sh   (idempotent, only touches completed/ files with non-null horizon)

## RCA

**Symptom:** CTL-030 - T-2405 in .tasks/completed/ had horizon='now' (expected: null).

**Root cause:** TRANSIENT/ALREADY FIXED. T-2405's horizon is currently 'null' (verified). The finding was emitted on 2026-07-02 but was resolved by T-2435 migration (per handover note: "T-2497: Verify 4 CTL-030 findings resolved by T-2435 migration").

**Why structurally allowed:** CTL-030 detector caught the inconsistency. T-2435 migration fixed horizon values in completed tasks.

**Prevention:** Already resolved - T-2405 horizon is now correct (null).

## Acceptance Criteria

### Agent
- [x] Root cause identified: TRANSIENT - already fixed by T-2435
- [x] Verified: T-2405 horizon is currently 'null' (correct)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0

## Updates

### 2026-07-02T18:34:40Z — audit-emit-task
- **Action:** Created by audit --emit-tasks
- **Finding:** fail: CTL-030: T-2405 horizon inconsistency

### 2026-07-03T22:50:00Z — verification
- **Action:** Verified T-2405 horizon is currently 'null' (correct)
- **Note:** Finding was already resolved by T-2435 migration


## Reviewer Verdict (v1.5)

- **Scan ID:** R-62e80f59
- **Timestamp:** 2026-07-03T22:46:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-030: T-2405 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0`

### 2026-07-03T22:46:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
