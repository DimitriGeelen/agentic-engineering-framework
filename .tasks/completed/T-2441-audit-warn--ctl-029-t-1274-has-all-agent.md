---
id: T-2441
name: "Audit WARN — CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — c..."
description: >
  Audit WARN — CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — c...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 0fe7b57604be21f5c9e669052c8ab3034e85a164
tags: [audit-finding, severity:warn, section:CTL-029]
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
created: 2026-07-02T18:37:24Z
last_update: 2026-07-03T23:51:18Z
date_finished: 2026-07-03T23:51:18Z
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

# T-2441: Audit WARN — CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — c...
## Trigger

Audit run: 2026-07-02T18:37:24Z
Finding: CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — completable, not closed

## Finding

```
CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — completable, not closed
```

Mitigation: Run: bin/fw task update T-1274 --status work-completed

## RCA

**Symptom:** Audit CTL-029 detector flagged T-1274 as having all Agent ACs ticked but status='started-work'.

**Root cause:** OPERATIONAL — T-1274 is a legitimate partial-complete task. It has 5 Agent ACs (all ticked), no unchecked Human ACs, but has a GO Recommendation section. The task correctly has `owner: human` and is waiting in active/ for human review of the recommendation per the partial-complete pattern (T-193, L-461). The fix (T-1431) has already been completed; this task is just waiting for human closure approval.

**Why structurally allowed:** CTL-029 detects completable-but-not-completed tasks, which includes both bugs (forgotten tasks) and legitimate partial-completes (waiting for human decision). The detector cannot distinguish between these two cases without parsing Recommendation structure.

**Prevention:** None needed — this is expected behavior. The task will be completed once the human reviews the GO recommendation and runs `fw task update T-1274 --status work-completed`.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — completable, not closed" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-cab282c6
- **Timestamp:** 2026-07-03T23:51:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-029: T-1274 has all Agent ACs ticked but status='started-work' — completable, not closed" && exit 1 || exit 0`

### 2026-07-03T23:51:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
