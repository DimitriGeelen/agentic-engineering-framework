---
id: T-2421
name: "Audit WARN — Uncommitted changes present"
description: >
  Audit WARN — Uncommitted changes present

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 5d2f37c5fde0edebf162ef3f7645ad438a6809b0
tags: [audit-finding, severity:warn, section:audit]
owner: agent
horizon: null
components: [agents/task-create/update-task.sh, lib/review.sh]
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
created: 2026-07-02T17:02:25Z
last_update: 2026-07-02T17:15:03Z
date_finished: 2026-07-02T17:15:03Z
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

# T-2421: Audit WARN — Uncommitted changes present
## Trigger

Audit run: 2026-07-02T17:02:25Z
Finding: Uncommitted changes present

## Finding

```
Uncommitted changes present
```

Mitigation: Commit changes with task reference or stash

## RCA

**Symptom:** Audit WARN on "Uncommitted changes present" during active session

**Root cause:** Active development session with work committed incrementally. At audit run time (17:02:25Z), there were uncommitted changes (tracking files, task metadata updates from BVP estimator sweep).

**Why structurally allowed:** This is a transient warning by design. The audit reminds agents to commit regularly during long sessions. The warning disappears after committing.

**Prevention:** Not a bug - this is the feedback loop working correctly. The audit detects uncommitted state → emits task → agent commits → warning resolves. This task demonstrates the T-2352 autotuning arc functioning as intended.

## Acceptance Criteria

### Agent
- [x] Root cause identified: transient warning during active session, resolved by committing
- [x] Determination: transient, working as intended - commit cadence reminder
- [x] Committed T-2420/T-2421 RCA work (e1755ef3e) - significant uncommitted changes now committed

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "Uncommitted changes present" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-e55a7fc1
- **Timestamp:** 2026-07-02T17:15:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "Uncommitted changes present" && exit 1 || exit 0`

### 2026-07-02T17:15:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
