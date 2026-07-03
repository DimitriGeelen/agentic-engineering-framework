---
id: T-100081
name: "Audit WARN — CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide c..."
description: >
  Audit WARN — CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide c...

status: started-work
workflow_type: build
audit_severity: warn
audit_finding_hash: d1c6a0c5c6d0bc7fcf107dae8d84b49dfedc265c
tags: [audit-finding, severity:warn, section:CTL-012]
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
created: 2026-07-03T07:36:39Z
last_update: 2026-07-03T07:36:39Z
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

# T-100081: Audit WARN — CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide c...
## Trigger

Audit run: 2026-07-03T07:36:39Z
Finding: CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide ceremony

## Finding

```
CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide ceremony
```

Mitigation: Auto-tick markers present but ## Decision section empty — run: fw inception decide T-1905 go

## RCA

**Symptom:** Audit CTL-012-MISSING-DECIDE flagged inception task completed without `fw inception decide` ceremony.

**Root cause:** Inception task was manually moved to completed/ without running the decision command. The framework enforces decision recording via commit-msg hook (blocks after 2 exploration commits) but has no gate at task completion.

**Why structurally allowed:** Agent can manually `git mv` task files or use `--skip-*` flags to bypass gates. The commit-msg hook catches most cases but doesn't cover manual file moves.

**Prevention:** (1) Strengthen commit-msg hook to check completed inception tasks on commit; (2) Add PreToolUse gate on `git mv` operations; (3) Human should run `fw inception decide` to record decision retroactively if the inception outcome is clear.

## Acceptance Criteria

### Agent
- [x] Root cause identified: Missing decision ceremony
- [x] Documented in RCA section
- [ ] Human determines if decision can be recorded retroactively
## Acceptance Criteria

### Agent
- [ ] Root cause identified and documented in RCA section
- [ ] Fix implemented (or determination that finding is false positive / transient)
- [ ] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide ceremony" && exit 1 || exit 0

## Updates

### 2026-07-03T07:36:39Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide ceremony
- **Context:** Auto-generated task for audit finding hash d1c6a0c5c6d0bc7fcf107dae8d84b49dfedc265c

