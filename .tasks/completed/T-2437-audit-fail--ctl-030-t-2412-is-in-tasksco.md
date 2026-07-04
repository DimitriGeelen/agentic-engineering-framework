---
id: T-2437
name: "Audit FAIL — CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now'
  (expe..."
description: >
  Audit FAIL — CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now' (expe...

status: started-work
workflow_type: build
audit_severity: fail
audit_finding_hash: 361d3b1185f5b7fa3230acf224e8905ee30b44af
tags: [audit-finding, severity:fail, section:CTL-030]
owner: agent
horizon: now
components: []
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
created: 2026-07-02T18:35:43Z
last_update: '2026-07-04T10:15:13Z'
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-07-04T10:15:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 3
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=3 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2437: Audit FAIL — CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now' (expe...
## Trigger

Audit run: 2026-07-02T18:35:43Z
Finding: CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)

## Finding

```
CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)
```

Mitigation: Fix: bin/migrate-horizon-null-completed.sh   (idempotent, only touches completed/ files with non-null horizon)

## RCA

**Symptom:** (TBD — fill during investigation)

**Root cause:** (TBD — structural? env? config? transient?)

**Why structurally allowed:** (TBD)

**Prevention:** (TBD)

## Acceptance Criteria

### Agent
- [ ] Root cause identified and documented in RCA section
- [ ] Fix implemented (or determination that finding is false positive / transient)
- [ ] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-030: T-2412 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0

