---
id: T-2432
name: "Audit WARN — CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='starte..."
description: >
  Audit WARN — CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='starte...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 4945e6107b72585830746936cc3fe989a5810108
tags: [audit-finding, severity:warn, section:CTL-028]
owner: agent
horizon: null
tags: []
components: [bin/fw]
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
created: 2026-07-02T18:33:38Z
last_update: 2026-07-03T22:42:56Z
date_finished: 2026-07-03T22:42:56Z
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

# T-2432: Audit WARN — CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='starte...
## Trigger

Audit run: 2026-07-02T18:33:38Z
Finding: CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)

## Finding

```
CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)
```

Mitigation: Fix: bin/fw task update T-2405 --status work-completed --force, or hand-edit frontmatter to status: work-completed + set date_finished

## RCA

**Symptom:** CTL-028 audit finding - T-2405 is in .tasks/completed/ but frontmatter has status='started-work' instead of 'work-completed'.

**Root cause:** DATA INCONSISTENCY (same class as T-2431). T-2405 was moved to .tasks/completed/ without updating frontmatter fields via `fw task update`. File location and status field were out of sync.

**Why structurally allowed:** Direct file moves (git mv, hand edits) can bypass `fw task update` enforcement. CTL-028 detector catches this in daily audit.

**Prevention:** Fixed by hand-editing frontmatter: status=work-completed, date_finished=2026-06-15T15:15:05Z (using last_update).

## Acceptance Criteria

### Agent
- [x] Root cause identified: file location/frontmatter status inconsistency (same class as T-2431)
- [x] Fix implemented: hand-edited T-2405 frontmatter (status + date_finished)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)" && exit 1 || exit 0

## Updates

### 2026-07-02T18:33:35Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-028: T-2405 status inconsistency
- **Context:** Auto-generated task for audit finding hash (from audit)

### 2026-07-03T22:44:00Z — fix [manual-edit]
- **Action:** Fixed T-2405 frontmatter inconsistency
- **Change:** status: started-work → work-completed; date_finished: null → 2026-06-15T15:15:05Z
- **File:** .tasks/completed/T-2405-fw-review-queue---arc-filter-arc-focused.md


## Reviewer Verdict (v1.5)

- **Scan ID:** R-bb952cc1
- **Timestamp:** 2026-07-03T22:42:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-028: T-2405 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)" && exit 1 || exit 0`

### 2026-07-03T22:42:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
