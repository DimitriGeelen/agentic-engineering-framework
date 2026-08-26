---
id: T-3180
name: "decided inception page still offers Record decision as its only affordance
  - the one remaining action is closure and it is on no button"
description: >
  Operator-facing half of T-3175. T-3175 made decided-but-unclosed inceptions VISIBLE
  (/approvals section 'Decided — awaiting closure', 2 entries: T-2715, T-2876). But
  the page that section links to still renders the pre-decision form. Measured 2026-08-26
  on a running Watchtower: /inception/T-2715 and /inception/T-2876 both return 200
  and both carry name="decision" + a 'Record decision' control, despite each already
  carrying a recorded GO in its body. There is no close control on either. So the
  operator follows a link that says 'you already decided this' and arrives at a form
  asking them to decide it. This is the exact shape that produced the 2026-08-26 pushback
  ('Why the fucking hell do you keep asking for these inceptions? I've go'd them several
  times'): the framework re-presents a decision the operator already made, because
  the render is keyed on the page's route rather than on whether a decision exists
  in the body. lib/decided_unclosed.py:extract_decision already computes the needed
  predicate and is imported by web/blueprints/approvals.py - the inception render
  surface does not consult it.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
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
created: 2026-08-26T18:15:16Z
last_update: 2026-08-26T19:33:00Z
date_finished: 2026-08-26T19:33:00Z
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
  - ts: '2026-08-26T18:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T18:30:16Z'
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

# T-3180: decided inception page still offers Record decision as its only affordance - the one remaining action is closure and it is on no button

## Context

### Correction to this task's original framing

Filed 2026-08-26 claiming the page "still renders a pre-decision form" and that the
banner had not noticed the recorded GO. **That was wrong, and the error was mine.** The
original claim came from a case-insensitive grep for `record decision` which matched
*prose inside the task body* ("Record decision via the Watchtower form or the…"), plus
`name="decision"` which is present on any decision form including the superseding one.

Re-measured properly against the running Watchtower:

- `/inception/T-2715` renders `decision-banner go`. The banner is correct.
- The form header renders **"Record Superseding Decision"**, not "Record Decision", and
  carries an explanatory note. `web/templates/inception_detail.html:490` already branches
  on `dec == 'pending'`. That part of the UI was built correctly and I mis-read it.

### What is actually wrong, verified

Enumerating every `action=` on the page returns exactly one: `/inception/<id>/decide`.
**There is no close control anywhere on it.** And `/review/T-2715` 302s to
`/inception/T-2715` (the T-2125/T-2129 class-correct redirect), so both routes converge
on the same page.

So a decided-but-unclosed inception has **no closing affordance in Watchtower at all**.
The one remaining action — the whole point of T-3175's new section — is on no button on
any page. `fw task update --status work-completed` from a terminal is the only way, and
that is a CLI handoff, which §T-679 exists to prevent.

### This is a defect I shipped

T-3175's `/approvals` section says, in copy I wrote: *"Close it from
`/inception/T-XXXX`."* That instruction points at a page that cannot do it. Making the
state visible without making it actionable moves the operator from "I can't find it" to
"I found it and there is no button", which is a smaller problem but the same shape — and
it is worse for having been introduced by the fix for the original one.

Sibling to T-2347 (arc actions surfaced as CLI instead of Watchtower URLs), and the
reason that rule exists.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/inception/<id>` renders a **close** control when the task is in `active/` AND
      carries a concluding decision (GO or NO-GO) AND its status is not already
      `work-completed`. Today the only `action=` on that page is
      `/inception/<id>/decide` — measured, not assumed.
- [x] The close control is absent on a `pending` inception (nothing to close), absent on
      a DEFER (a park, not a pending closure — same exclusion as
      `lib/decided_unclosed.py:CONCLUDING`), and absent on a task already in `completed/`.
      Three silence controls; without them "show a close button when decided" and "show a
      close button" are the same diff.
- [x] The predicate is `lib/decided_unclosed.is_decided_unclosed`, imported — NOT a
      fourth reimplementation of "is this decided". `/approvals` and `/inception` must
      agree by construction, because a disagreement is exactly what produced this bug:
      one surface said "you already decided this", the other offered to re-decide it.
- [x] Closing from the page routes through the same path as
      `fw task update --status work-completed`, so every gate still fires (Human ACs,
      Verification, sovereignty). The button must not be a way to skip what the CLI
      enforces — if a gate refuses, the page shows the refusal.
- [x] The `/approvals` "Decided — awaiting closure" copy is verified against the page it
      names. It currently reads "Close it from /inception/T-XXXX" and that page has no
      close control, so the instruction I shipped in T-3175 points at a dead end.
- [x] A test pins BOTH halves against the live blueprint: decided+active → close control
      present; pending / DEFER / completed → absent.

### Human
- [ ] [REVIEW] The close card reads as *finish this* rather than *decide this again*, and
      sits where you would look for it.
      **Steps:**
      1. Open http://192.168.10.107:3000/inception/T-2715
      2. Read down the page from the green "Decision: GO" banner.
      **Expected:** the first action you meet is "Decision recorded — one step left" with a
      `Close T-2715` button; the "Record Superseding Decision" form is below it and reads
      as the rarer option. You should not feel asked to re-decide anything.
      **If not:** say whether the problem is the order of the two cards or the wording of
      the first one — they are separate fixes.

<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification

python3 -m pytest tests/unit/test_inception_close_card.py tests/unit/test_decided_unclosed.py -q > /tmp/.t3180 2>&1 && grep -qE "^1[0-9] passed" /tmp/.t3180
# the close card renders on a decided-unclosed inception (live page, not source)
curl -sf "$(bin/fw watchtower url)/inception/T-2715" -o /tmp/.t3180a && grep -q "close-inception" /tmp/.t3180a && grep -q "/api/task/T-2715/complete" /tmp/.t3180a
# silence control: a pending inception has no close card
curl -sf "$(bin/fw watchtower url)/inception/T-2668" -o /tmp/.t3180b && ! grep -q "close-inception" /tmp/.t3180b
# silence control: a DEFER is a park, not a pending closure
curl -sf "$(bin/fw watchtower url)/inception/T-2670" -o /tmp/.t3180c && ! grep -q "close-inception" /tmp/.t3180c
# silence control: an already-closed inception
curl -sf "$(bin/fw watchtower url)/inception/T-3097" -o /tmp/.t3180d && ! grep -q "close-inception" /tmp/.t3180d
# one predicate, not two: the blueprint delegates to lib/ rather than re-deriving
grep -q "decided_unclosed.is_decided_unclosed" web/blueprints/inception.py

## RCA

**Symptom.** `/approvals` told the operator "you already decided these — close it from
`/inception/T-XXXX`", and that page had no close control. `/review/<id>` 302s to the same
page, so a decided-but-unclosed inception had no closing affordance anywhere in
Watchtower.

**Root cause.** T-3175 solved *visibility* and stopped there. Making a stuck state
visible is not the same as making it actionable, and the copy I shipped asserted an
affordance that did not exist. The operator moves from "I can't find it" to "I found it
and there is no button" — smaller, same shape, and worse for having been introduced by
the fix for the original.

**A wrong diagnosis on the way, recorded because it matters.** This task was first filed
claiming the page rendered a *pre-decision* form and had not noticed the recorded GO.
That was false. It came from a case-insensitive grep for `record decision` that matched
prose inside the task body, plus `name="decision"` which any decision form carries. The
template already branched correctly on `dec == 'pending'` and rendered "Record
Superseding Decision". Two greps are not a measurement; enumerating every `action=` on
the page was, and it is what found the real defect. The claim had already been stated to
the operator as measured before it was checked.

**Prevention.** The blueprint imports `lib/decided_unclosed.is_decided_unclosed` rather
than re-deriving it, and `test_blueprint_helper_agrees_with_the_shared_predicate` asserts
the two surfaces cannot drift. Drift between surfaces answering the same question is what
produced the original T-3175 gap; a second copy here would have guaranteed a third one.
Mutation-verified: replacing the delegation with a local re-derivation turns that test red.

## Recommendation

**Recommendation:** GO — close it.

**Rationale:** All six Agent ACs pass, verified against the live page rather than the
source. The one thing left is a placement-and-tone judgment: whether the close card reads
as *finish this* rather than *decide this again*, and whether putting it above the
superseding-decision form is the right order. That is exactly the perception this whole
task exists to fix, and I am the wrong party to score it — I am the one who mis-read the
page in the first place.

**Evidence:**
- `/inception/T-2715` and `/inception/T-2876` now render `close-inception` +
  `/api/task/<id>/complete`; before this change the only `action=` on either page was
  `/inception/<id>/decide`.
- Three silence controls hold on the live server: pending (T-2668), DEFER (T-2670), and
  already-closed (T-3097) all render no close card.
- Closing routes through the existing `/api/task/<id>/complete`, i.e. `fw task update
  --status work-completed` with the human-action flags — every gate still fires, and a
  refusal renders instead of being swallowed.
- The blueprint imports `lib/decided_unclosed.is_decided_unclosed`;
  `test_blueprint_helper_agrees_with_the_shared_predicate` fails if it ever re-derives.
- Mutation-tested, 3 legs: always-true predicate (3 red), card removed (1 red — the
  defect itself), re-derived predicate (1 red, caught by the agreement test).
- Correction recorded in `## RCA`: this task's original framing was wrong and I had
  already stated it to you as measured. Two greps are not a measurement.

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

### 2026-08-26T18:15:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3180-decided-inception-page-still-offers-reco.md
- **Context:** Initial task creation

### 2026-08-26T19:18:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d09f0984
- **Timestamp:** 2026-08-26T19:33:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-26T19:33:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
