---
id: T-100075
name: "Audit WARN — CTL-029: T-464 has all Agent ACs ticked but status='started-work' — co..."
description: >
  Audit WARN — CTL-029: T-464 has all Agent ACs ticked but status='started-work' — co...

status: started-work
workflow_type: build
audit_severity: warn
audit_finding_hash: b71f933aa03ac24ea56abda9372eb0d8203feaac
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
created: 2026-07-03T07:34:30Z
last_update: 2026-07-03T07:34:30Z
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

# T-100075: Audit WARN — CTL-029: T-464 has all Agent ACs ticked but status='started-work' — co...
## Trigger

Audit run: 2026-07-03T07:34:30Z
Finding: CTL-029: T-464 has all Agent ACs ticked but status='started-work' — completable, not closed

## Finding

```
CTL-029: T-464 has all Agent ACs ticked but status='started-work' — completable, not closed
```

Mitigation: Run: bin/fw task update T-464 --status work-completed

## RCA

**Symptom:** CTL-029 flagged task as "completable but not closed" (all Agent ACs ticked, status=started-work).

**Root cause:** FALSE POSITIVE - target task is partial-complete (owner=human, unchecked Human ACs). CTL-029 detector doesn't check for Human AC presence.

**Why structurally allowed:** CTL-029 designed to catch genuinely completable tasks. Partial-complete pattern (Agent done, Human pending) mimics this signal but is correct state.

**Prevention:** Enhance CTL-029 to skip tasks with owner=human or unchecked Human ACs. Full analysis: `docs/reports/T-100066-ctl-029-false-positive-class.md`

## Acceptance Criteria

### Agent
- [x] Root cause identified: FALSE POSITIVE (partial-complete task)
- [x] Documented in RCA section with reference to analysis doc
- [x] No fix needed - target task state is correct

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-029: T-464 has all Agent ACs ticked but status='started-work' — completable, not closed" && exit 1 || exit 0

## Updates

### 2026-07-03T07:34:30Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-029: T-464 has all Agent ACs ticked but status='started-work' — completable, not closed
- **Context:** Auto-generated task for audit finding hash b71f933aa03ac24ea56abda9372eb0d8203feaac

