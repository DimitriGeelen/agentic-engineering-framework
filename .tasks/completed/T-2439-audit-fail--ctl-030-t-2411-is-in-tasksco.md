---
id: T-2439
name: "Audit FAIL — CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expe..."
description: >
  Audit FAIL — CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expe...

status: work-completed
workflow_type: build
audit_severity: fail
audit_finding_hash: 893514fe89062be3756b3c5124200907325d2ced
tags: [audit-finding, severity:fail, section:CTL-030]
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/config.sh, lib/notify.sh, web/blueprints/config.py]
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
created: 2026-07-02T18:36:33Z
last_update: 2026-07-03T23:49:55Z
date_finished: 2026-07-03T23:49:55Z
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

# T-2439: Audit FAIL — CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expe...
## Trigger

Audit run: 2026-07-02T18:36:33Z
Finding: CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)

## Finding

```
CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)
```

Mitigation: Fix: bin/migrate-horizon-null-completed.sh   (idempotent, only touches completed/ files with non-null horizon)

## RCA

**Symptom:** Audit CTL-030 detector flagged T-2411 as being in `.tasks/completed/` with `horizon='now'` instead of `null`.

**Root cause:** TRANSIENT — T-2411's horizon field was already corrected to `null` by T-2435 (bin/migrate-horizon-null-completed.sh) before this audit finding was filed. Verified `grep "^horizon:" .tasks/completed/T-2411*.md` shows `horizon: null`.

**Why structurally allowed:** Audit runs asynchronously relative to remediation work. T-2435 fixed the underlying issue (migrated all completed/ tasks to horizon=null) between audit detection and triage.

**Prevention:** None needed — finding is stale. The detector (CTL-030) and remediation script (T-2435 migration) are both working as designed.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-b8e1048a
- **Timestamp:** 2026-07-03T23:49:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-030: T-2411 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0`

### 2026-07-03T23:49:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
