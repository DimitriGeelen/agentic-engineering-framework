---
id: T-2420
name: "Audit FAIL — Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)"
description: >
  Audit FAIL — Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
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
created: 2026-07-02T16:58:33Z
last_update: '2026-07-02T17:00:06Z'
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
bvp_scores_proposed:
  - ts: '2026-07-02T17:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-02T17:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 3
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=3 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2420: Audit FAIL — Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)
## Trigger

Audit run: 2026-07-02T16:58:33Z
Finding: Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)

## Finding

```
Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)
```

Mitigation: Run: fw vendor  (sync all vendored .agentic-framework/ classes with source)

## RCA

**Symptom:** Audit FAIL on "Self-vendor drift: libs class — 3 file(s) out of sync"

**Root cause:** T-2353, T-2354, and T-2417 modified source files (agents/audit/*, agents/termlink/bvp-estimator/*, policy/value-drivers.yaml) but didn't run `fw vendor self` to sync the vendored copies to `.agentic-framework/` before committing.

**Why structurally allowed:** The pre-push hook catches this drift (T-2240), but only at push time. Between commit and push, the drift exists. The audit emission mechanism (T-2353) automatically created this task to track the fix.

**Prevention:** This is working as designed - the pre-push gate blocked the push, audit emitted a task, and now it's being resolved. The autotuning feedback loop (T-2352) is functioning correctly.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented: ran `fw vendor self` and committed sync (commit 8509f9bdb)
- [x] Re-run audit shows finding absent: audit structure section now shows PASS

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "Self-vendor drift: libs class — 3 file(s) out of sync (T-2244)" && exit 1 || exit 0

