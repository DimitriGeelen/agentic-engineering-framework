---
id: T-100185
name: "create_task.bats inception tests fail under CLAUDECODE=1 (T-2207 gate not stripped)"
description: >
  create_task.bats inception tests fail under CLAUDECODE=1 (T-2207 gate not stripped)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/create_task.bats]
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
created: 2026-07-04T21:37:29Z
last_update: 2026-07-04T21:43:45Z
date_finished: 2026-07-04T21:43:45Z
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

# T-100185: create_task.bats inception tests fail under CLAUDECODE=1 (T-2207 gate not stripped)

## Context

4 inception-filing tests in `tests/unit/create_task.bats` fail whenever the suite runs from inside a Claude Code session: they inherit `CLAUDECODE=1`, so the T-2207 recommendation-completeness gate in `create-task.sh` refuses `--type inception` without `--recommendation`/`--rationale`. Tests pass in clean CI, fail locally — a hermeticity gap (sibling of L-490 / T-2454 FW_HERMETIC class). Verified pre-existing on pristine origin/master via git-stash baseline on 2026-07-04.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The inception-filing tests in tests/unit/create_task.bats pass when run with CLAUDECODE=1 in the environment (simulating a Claude Code session)
- [x] Fix neutralises the inherited env for test invocations (env -u CLAUDECODE or equivalent) rather than weakening the T-2207 gate itself
- [x] Full create_task.bats suite green under CLAUDECODE=1

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

git show origin/master:tests/unit/create_task.bats > /tmp/.t100185 && grep -q "unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED" /tmp/.t100185
grep -q "T-100185: setup strips inherited CLAUDECODE" /tmp/.t100185

## RCA

**Symptom:** 4 inception-filing tests in tests/unit/create_task.bats (16/21/22/23) fail whenever the suite runs from inside a Claude Code session; same tests pass in clean CI.

**Root cause:** bats inherits the invoking environment. Under a Claude Code session `CLAUDECODE=1` leaks into the test process, arming the T-2207 recommendation-completeness gate in create-task.sh — `--type inception` without `--recommendation`/`--rationale` is then refused, so success-path tests fail and failure-path tests fail with the wrong error.

**Why structurally allowed:** the suite's setup() sandboxed TASKS_DIR/PROJECT_ROOT but never sandboxed the *gate-arming* environment. The framework's env-conditional gates (CLAUDECODE-keyed) postdate the suite (T-921 origin), and no hermeticity convention existed until L-490/FW_HERMETIC (T-2454) — this suite was written before that class was named.

**Prevention:** setup() now strips CLAUDECODE + both T-2207 bypass vars for every test, and a runtime pin test asserts the strip is in effect — if the unset line is ever removed, the pin fails in clean CI too, not just locally.

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

### 2026-07-04T21:37:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100185-createtaskbats-inception-tests-fail-unde.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8f91ef1
- **Timestamp:** 2026-07-04T21:43:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-04T21:43:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
