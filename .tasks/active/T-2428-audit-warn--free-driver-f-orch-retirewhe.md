---
id: T-2428
name: "Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete..."
description: >
  Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...

status: started-work
workflow_type: build
audit_severity: warn
audit_finding_hash: 3d6037d518b559e687a0801455de7b4c56778435
tags: [audit-finding, severity:warn, section:audit]
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
created: 2026-07-02T18:32:08Z
last_update: 2026-07-02T18:32:08Z
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

# T-2428: Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...
## Trigger

Audit run: 2026-07-02T18:32:08Z
Finding: free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire

## Finding

```
free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire
```

Mitigation: Review the driver; if truly retired, comment it out or move to candidates section. Silence with FW_RETIRE_WHEN_ADVISORY=0.

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
bin/fw audit 2>&1 | grep -q "free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire" && exit 1 || exit 0

