---
id: T-99978
name: "Audit WARN — CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — c..."
description: >
  Audit WARN — CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — c...

status: started-work
workflow_type: build
audit_severity: warn
audit_finding_hash: 9ef8730bc2495c656bf1fe4b5a9a3b7ee3b33520
tags: [audit-finding, severity:warn, section:CTL-029]
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
created: 2026-07-02T23:09:16Z
last_update: 2026-07-02T23:09:16Z
date_finished: null
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

# T-99978: Audit WARN — CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — c...
## Trigger

Audit run: 2026-07-02T23:09:16Z
Finding: CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — completable, not closed

## Finding

```
CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — completable, not closed
```

Mitigation: Run: bin/fw task update T-2121 --status work-completed

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
bin/fw audit 2>&1 | grep -q "CTL-029: T-2121 has all Agent ACs ticked but status='started-work' — completable, not closed" && exit 1 || exit 0

