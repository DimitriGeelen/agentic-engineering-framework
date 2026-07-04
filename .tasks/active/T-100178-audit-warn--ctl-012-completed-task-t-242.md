---
id: T-100178
name: "Audit WARN — CTL-012: Completed task T-2429 has unchecked AC"
description: >
  Audit WARN — CTL-012: Completed task T-2429 has unchecked AC

status: captured
workflow_type: build
audit_severity: warn
audit_finding_hash: 2f464c62e84b3549d42baf81f0524ea1a172d540
tags: [audit-finding, severity:warn, section:CTL-012]
owner: agent
horizon: later
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
created: 2026-07-04T17:04:46Z
last_update: '2026-07-04T17:15:03Z'
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
  - ts: '2026-07-04T17:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 3
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=3 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T17:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=4 
      (fm:audit_severity=warn); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100178: Audit WARN — CTL-012: Completed task T-2429 has unchecked AC
## Trigger

Audit run: 2026-07-04T17:04:46Z
Finding: CTL-012: Completed task T-2429 has unchecked AC

## Finding

```
CTL-012: Completed task T-2429 has unchecked AC
```

Mitigation: Review task completion — AC gate may have been bypassed

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
bin/fw audit 2>&1 | grep -q "CTL-012: Completed task T-2429 has unchecked AC" && exit 1 || exit 0

## Updates

### 2026-07-04T17:04:46Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-012: Completed task T-2429 has unchecked AC
- **Context:** Auto-generated task for audit finding hash 2f464c62e84b3549d42baf81f0524ea1a172d540

