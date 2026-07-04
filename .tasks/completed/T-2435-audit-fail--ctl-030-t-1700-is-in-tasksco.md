---
id: T-2435
name: "Audit FAIL — CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expe..."
description: >
  Audit FAIL — CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expe...

status: work-completed
workflow_type: build
audit_severity: fail
audit_finding_hash: 63b7eb2a1febb878fa53e82ed93a20acdc2cecb1
tags: [audit-finding, severity:fail, section:CTL-030]
owner: agent
horizon: null
components: [C-004, bin/fw, lib/paths.sh, tests/unit/lib_paths.bats]
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
created: 2026-07-02T18:34:53Z
last_update: 2026-07-02T20:18:38Z
date_finished: 2026-07-02T20:18:38Z
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

# T-2435: Audit FAIL — CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expe...
## Trigger

Audit run: 2026-07-02T18:34:53Z
Finding: CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)

## Finding

```
CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)
```

Mitigation: Fix: bin/migrate-horizon-null-completed.sh   (idempotent, only touches completed/ files with non-null horizon)

## RCA

**Symptom:** T-1700 and ~1828 other completed tasks have `horizon: now/next/later` stored in frontmatter instead of `horizon: null`. Audit CTL-030 flags these as incorrect because render-time derives 'past' from `_location == 'completed'` (T-2160), making the stored value behaviorally irrelevant but semantically wrong.

**Root cause:** Before T-1068 invariants existed, tasks were completed without nulling the horizon field. The `update-task.sh --status work-completed` flow moves tasks to `completed/` but historically didn't enforce `horizon: null`. T-2160 changed render semantics to ignore the stored value, but legacy data remained dirty.

**Why structurally allowed:** No completion gate enforced `horizon: null` on the transition to `completed/`. The render refactor (T-2160) made the field irrelevant, removing the urgency to clean historical data. No periodic audit flagged the hygiene gap until CTL-030 was added.

**Prevention:** (1) Migration script `bin/migrate-horizon-null-completed.sh` created in T-2161 — run now to clean corpus. (2) Add gate to `update-task.sh --status work-completed` to enforce `horizon: null` before move (future enhancement). (3) CTL-030 audit check prevents accumulation going forward.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented: run `bash bin/migrate-horizon-null-completed.sh` to null all horizon fields in completed/ (1981 files changed)
- [x] Re-run audit shows finding absent — T-1700 verified: `horizon: null` (CTL-030 resolved)

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-882b23d7
- **Timestamp:** 2026-07-02T20:18:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — Fix implemented: run `bash bin/migrate-horizon-null-completed.sh` to null all horizon fields in completed/ (1981 files changed)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=bin/migrate-horizon-null-completed.sh in: Fix implemented: run `bash bin/migrate-horizon-null-completed.sh` to null all horizon fields in completed/ (1981 files changed)`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-030: T-1700 is in .tasks/completed/ but stored horizon='now' (expected: null/absent — render derives 'past' from _location, T-2160)" && exit 1 || exit 0`

### 2026-07-02T20:18:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
