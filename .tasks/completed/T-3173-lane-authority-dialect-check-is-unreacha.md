---
id: T-3173
name: "lane authority dialect check is unreachable for lanes with no task nodes, so
  real typos compile silently"
description: >
  Inbound correction from 001-CashWeb-Lightspeed-Ecwid-integration (2026-08-26,
  follow-up to their G-055 / our G-091). They narrowed their own repro and withdrew
  a
  prediction; measuring the narrowed form at HEAD surfaced a DISTINCT defect they
  did
  not claim. tools/bpmn_to_tasks.py collects lane-authority folds INSIDE the task-node
  loop, which `continue`s at :424 on every node whose tag is not in TASK_TAGS (:51
  =
  userTask/serviceTask/scriptTask). unknown_auth is populated at :481, downstream
  of
  that guard, and the dialect WARNs at :501-521 are emitted from unknown_auth alone.
  Consequence: a lane whose flowNodeRefs are all events or gateways never reaches
  the
  check, so its <aef:laneMeta authority> is never read and never validated. This is
  not
  only the `external` case (T-3172) - it swallows GENUINE typos. Measured at HEAD
  on a
  two-lane fixture whose second lane holds only intermediateCatchEvents:
  authority="external" -> rc 0, zero warnings; the same fixture with authority="overlrd"
  (an unambiguous misspelling, in no vocabulary) -> rc 0, zero warnings. The
  typo-suspecting else-branch that exists precisely to catch that value is unreachable.
  Distinct from T-3172, which fixes WHICH values the dialect contains; this fixes
  WHETHER the dialect is consulted at all.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tools/bpmn_to_tasks.py, tests/unit/test_bpmn_to_tasks.py]
related_tasks: [T-3172, T-2717, T-2567]
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
created: 2026-08-26T15:37:21Z
last_update: 2026-08-26T18:08:18Z
date_finished: 2026-08-26T18:08:18Z
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
cost_estimate_proposed:
  - ts: '2026-08-26T15:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (2-components); tier=2 (workflow:build); effort=8 
      (lines=247,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T15:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3173: lane authority dialect check is unreachable for lanes with no task nodes, so real typos compile silently

## Context

The lane-authority dialect check is scoped to task-bearing lanes, so it never runs on a
lane whose nodes are all events or gateways. Found while verifying an inbound correction
from 001-CashWeb (they retracted a prediction; the retraction is what exposed this).

**Reproduction at HEAD (2026-08-26), two-lane fixture, second lane = two
`intermediateCatchEvent`s only:**

| `<aef:laneMeta authority=...>` on the events-only lane | rc | warnings |
|---|---|---|
| `external` (ratified by the frozen standard, absent from the compiler) | 0 | none |
| `overlrd` (unambiguous misspelling, in no vocabulary anywhere) | 0 | none |
| `external` **with one `serviceTask` added to the same lane** | 0 | 1 — the "very likely a typo" WARN, and the node compiles to `owner: agent` |

The third row is T-3172. The first two rows are this task: the value is never read, so
neither a ratified-but-unimplemented value nor a plain typo produces any signal.

**Code path:** `for node in root.iter()` (:421) → `if ntype not in TASK_TAGS and not
is_inception: continue` (:424) → … → `unknown_auth.setdefault(...)` (:481). The WARN
emitters at :501-521 iterate `unknown_auth` only. Nothing outside that loop reads
`lane_auth` (built at :403 by `_lane_authority`, :254) for validation purposes.

**Why this is the more dangerous half:** the T-3172 case at least announces itself, even
if it announces the wrong thing. This case is silent by construction — a diagram author
gets no signal that the compiler never read their authority choice. Same class as T-2552
and T-2557 (semantics dropped without a surface), except here the dropped thing is the
*validation*, not the semantics.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Lane-authority validation is lifted OUT of the task-node loop in
      `tools/bpmn_to_tasks.py`. Every lane carrying `<aef:laneMeta authority="...">`
      has its value checked against the dialect exactly once, regardless of what its
      flowNodeRefs contain — the check must not depend on the `continue` at :424
- [x] A lane whose flowNodeRefs are ALL non-task nodes (events, gateways) and whose
      `authority` is out-of-dialect (e.g. `overlrd`) emits the typo-suspecting WARN.
      Measured today at HEAD: it emits nothing, rc 0 — that is the regression this
      task closes
- [x] Warn-once semantics survive the lift: a lane is reported once, not once per
      node. Existing aggregation (`unknown_auth` keyed by `(authority, lane)`) already
      guarantees this for task lanes; the lifted check must not double-report a lane
      that has both task and non-task nodes
- [x] The dialect-valid cases stay silent on non-task lanes — `sovereignty`,
      `initiative` and `authority` on an events-only lane produce no NEW warning
      (`authority` keeps its existing T-2567/OBS-118 non-accusing message only where
      it already fired, i.e. where nodes actually fell back to name/type derivation)
- [x] Regression test in `tests/unit/test_bpmn_to_tasks.py` pins BOTH halves against
      an events-only-lane fixture: out-of-dialect value → exactly one WARN naming the
      lane; in-dialect value → zero WARNs. The fixture is committed, not inlined
- [x] Ordering with T-3172 is recorded in `## Decisions`: T-3172 changes WHICH values
      are in the dialect, this task changes WHETHER the dialect is consulted. Whichever
      lands second must not silently revert the other's fixture expectations

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification

# L-387: redirect then grep the file. P-011 runs each line under `set -eo pipefail`,
# so `cmd | grep -q` can exit 141 on SIGPIPE once the output grows past a pipe buffer.
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q > /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.out 2>&1 && tail -1 /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.out | grep -qE "^72 passed"
# the regression: a typo on an events-only lane is now caught (was silent, rc 0)
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/events-only-lane-sample.bpmn > /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.a 2>&1; grep -q "overlrd" /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.a && grep -q "very likely a typo" /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.a
# the silence control: a VALID value on the same shape stays quiet
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/events-only-valid-lane-sample.bpmn > /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.b 2>&1; test "$(grep -c 'laneMeta authority' /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.b)" = "0"
# warn-once: a lane WITH tasks is reported by the loop, not again by the lifted check
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/out-of-dialect-lane-sample.bpmn > /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.c 2>&1; test "$(grep -c 'laneMeta authority' /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.c)" = "1"
# T-3172's external case is undisturbed by the shared reporting region
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn > /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.d 2>&1; grep -q "emitted NO task skeleton" /tmp/claude-0/-opt-999-Agentic-Engineering-Framework/6f13df8a-65bc-4ac4-9bc8-cde8c902f86b/scratchpad/t3173.d

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

### 2026-08-26 — ordering against T-3172 and T-3176

- **Chose:** land T-3172 first (dialect membership), then T-3176 (unset reporting class),
  then this task (dialect *reachability*). All three edit the same `unknown_auth`
  reporting region and the same `AUTHORITY_*` constants.
- **Why:** the three answer different questions and must not be conflated. T-3172 changes
  WHICH values are in the dialect; T-3176 adds a class that is deliberately NOT in the
  dialect; this task changes WHETHER the dialect is consulted at all. Landing
  reachability first would have made the check reachable while still holding the wrong
  set — a lane laned `external` would have been loudly accused on more surfaces, not
  fewer. Each of the three has fixture assertions the other two must not revert;
  `test_lifted_check_does_not_disturb_the_t3172_external_case` pins that explicitly.
- **Rejected:** one combined fix. It would have produced a single diff in which the
  wrong-owner defect, the wording defect and the reachability defect were
  indistinguishable, and no mutation could have isolated any of them.

### 2026-08-26 — the lifted check fires ONLY on genuinely out-of-vocabulary values

- **Chose:** dialect-valid values and the `none` unset sentinel stay silent on a lane
  with no task nodes. Only a value in no vocabulary at all is reported there.
- **Why:** the two existing messages both explain something that HAPPENED — an owner
  fallback, or a dropped node. On a lane that emitted nothing there is no fallback to
  explain, so firing would say nothing and would fire on essentially every untouched
  events-only lane. That is the always-fires noise (L-527) the T-2717 split was built to
  remove, and rebuilding it here would have undone that work sideways.
- **Rejected:** reporting every lane whose authority is not in `AUTHORITY_OWNER`.
  Mutation-tested: 7 tests go red, including three that predate this task.

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

### 2026-08-26T15:37:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3173-lane-authority-dialect-check-is-unreacha.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1f695c8
- **Timestamp:** 2026-08-26T18:08:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-26T18:08:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
