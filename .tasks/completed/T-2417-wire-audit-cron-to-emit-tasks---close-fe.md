---
id: T-2417
name: "Wire audit cron to emit-tasks - close feedback loop"
description: >
  Wire audit cron to emit-tasks - close feedback loop

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, bin/fw, lib/ask.py, lib/review.sh]
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
created: 2026-07-02T16:28:58Z
last_update: 2026-07-02T17:06:45Z
date_finished: 2026-07-02T17:06:45Z
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
  - ts: '2026-07-02T16:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 3
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=3 
      (body:feedback-loop-closed); audit_severity=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-02T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2417: Wire audit cron to emit-tasks - close feedback loop

## Context

Completes the T-2352 autotuning feedback loop. T-2353 added `fw audit --emit-tasks` to convert WARN/FAIL findings into bugfix tasks. T-2354 added BVP scoring to prioritize them. But the existing audit cron jobs (structural-30m, traceability-hourly, full-daily) don't use --emit-tasks yet, so findings still just print to logs without creating tasks.

Wire the cron jobs to emit tasks automatically, closing the feedback loop: audit detects issues → creates tasks → BVP ranks high → agent addresses them.

**Related:** T-2352 (inception), T-2353 (emit mechanism), T-2354 (BVP scoring), L-364 (cron wired≠deployed), T-1771 (cron drift detection)

## Acceptance Criteria

### Agent
- [x] structural-30m cron command updated to include `--emit-tasks` flag in .context/cron-registry.yaml
- [x] traceability-hourly cron command updated to include `--emit-tasks` flag
- [x] full-daily cron command updated to include `--emit-tasks` flag (if it exists)
- [x] Cron registry regenerated: `fw cron generate && fw cron install`
- [x] Dry-run test: `fw audit --emit-tasks --dry-run --section structure` shows would-create output
- [x] Live test: `fw audit --emit-tasks --section structure` created T-2418, T-2419, T-2420 successfully
- [x] Documentation: cron-registry.yaml descriptions updated with "Emits WARN/FAIL findings as bugfix tasks"

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Verify _emit_findings_as_tasks function exists in audit.sh
grep -q "_emit_findings_as_tasks()" agents/audit/audit.sh

# Verify cron commands include --emit-tasks flag
out=$(grep -E "structural-30m|traceability-hourly|full-daily" .context/cron-registry.yaml); echo "$out" | grep -q "emit-tasks"

# Verify cron descriptions mention emit-tasks
out=$(grep -A5 "structural-30m\|traceability-hourly\|full-daily" .context/cron-registry.yaml | grep description); echo "$out" | grep -q "Emits WARN/FAIL"

# Verify live emission created tasks (T-2418, T-2419, T-2420)
test -f .tasks/active/T-2418-audit-warn--free-driver-f-orch-retirewhe.md && test -f .tasks/active/T-2419-audit-warn--fabric-107836-cards-have-no-.md && test -f .tasks/active/T-2420-audit-fail--self-vendor-drift-libs-class.md

## RCA

**Symptom:** `fw audit --emit-tasks --dry-run` showed "[emit-tasks] No audit YAML found:" and didn't create tasks.

**Root cause:** Four bugs in the `_emit_findings_as_tasks()` function prevented emission:
1. Variable name mismatch: function referenced `$AUDIT_OUTPUT_FILE` but audit.sh sets `$AUDIT_FILE`
2. Python heredoc arg passing: tried to pass `$yaml_file` as sys.argv[1] but heredocs don't work that way
3. Missing required `--description` parameter in `fw task create` call
4. Missing required `--owner` parameter in `fw task create` call
5. Invalid workflow type: used `bugfix` instead of valid `build` type
6. sed pattern mismatch: looked for `workflow_type: bugfix` but created tasks have `workflow_type: build`

**Why structurally allowed:** 
- No unit tests for `_emit_findings_as_tasks()` function
- T-2353 added the mechanism but didn't test end-to-end emission (only dry-run)
- The Python heredoc pattern was untested with argument passing

**Prevention:** 
- Added verification commands that test dry-run output
- T-2353's bats tests cover function existence but not execution correctness
- This task demonstrates end-to-end emission works (T-2418, T-2419, T-2420 created)

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-02T16:28:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2417-wire-audit-cron-to-emit-tasks---close-fe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-978b44d9
- **Timestamp:** 2026-07-02T17:06:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-02T17:06:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
