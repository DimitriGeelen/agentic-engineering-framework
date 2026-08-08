---
id: T-2881
name: "Onboarding gate false-positives on arc tags: \b regex matches inside arc:onboarding-curriculum"
description: >
  Onboarding gate false-positives on arc tags: \b regex matches inside arc:onboarding-curriculum

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-08T19:49:26Z
last_update: 2026-08-08T20:02:08Z
date_finished: 2026-08-08T20:02:08Z
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
  - ts: '2026-08-08T20:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T20:00:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2881: Onboarding gate false-positives on arc tags: \b regex matches inside arc:onboarding-curriculum

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `has_onboarding_tag` treats `onboarding` as a whole tag element, not a substring:
      `[onboarding]` and `[onboarding, ui]` match; `[arc:onboarding-curriculum]`,
      `[onboarding-notes]` and `[pre-onboarding]` do not
- [x] T-2877 (tagged `arc:onboarding-curriculum`, `owner: agent`) can carry an unticked
      `### Human` AC without being refused — the block that motivated this task is gone
- [x] The gate still refuses the real case it exists for: `tags: [onboarding]`,
      `owner: agent`, unticked `### Human` AC → rc=2 (asserted in the same suite, so the
      fix cannot be "stop refusing things")
- [x] The `owner: human` escape valve and the inception-with-human-owner allowance are
      unchanged; the existing onboarding-gate suites stay green
- [x] Teeth by durable mutation of live source (T-2874): restoring the `\b` regex makes the
      arc-tag case refuse again
- [x] **Second call site fixed in the same commit** — `check-active-task.sh`'s T-532 scan
      used `^tags:.*onboarding`, a looser form of the same conflation. Both sides ship
      together (L-399 producer/consumer parity)

## Measured Behaviour

Write-time gate (`check-onboarding-gate.py`), owner:agent + unticked `### Human` AC:

| tags | before | after |
|---|---|---|
| `[onboarding]` | rc=2 | rc=2 |
| `[onboarding, ui]` / `[ui, onboarding]` | rc=2 | rc=2 |
| `[arc:onboarding-curriculum]` | **rc=2** | **rc=0** |
| `[onboarding-notes]`, `[pre-onboarding]` | **rc=2** | **rc=0** |
| `[onboarding]` + `owner: human` | rc=0 | rc=0 |

Scan side (`check-active-task.sh` T-532 block), measured live against a sandbox project
with the fast-path marker cleared before **each** probe:

| active task set | rc |
|---|---|
| one task tagged `arc:onboarding-curriculum` | 0 — not treated as gated |
| one task tagged `onboarding`, `owner: agent` | 2 — still blocks (positive control) |
| one task tagged `onboarding`, `owner: human` | 0 — escape valve intact |
| real `onboarding` task + marker present | 0 — marker short-circuits (why this was latent) |

**A false negative during development, worth recording:** the first scan-side positive
control returned rc=0 and looked like the fix working. It was contamination — the hook
*writes* `.onboarding-complete` when it finds nothing to block on, so the earlier probe in
the same fixture had created the marker that made every later probe short-circuit. The
suite now clears the marker before each probe and pins that behaviour explicitly.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in the Verification block instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     No Human AC on this task: every criterion is a deterministic gate exit code.
-->

## Verification

out=$(bats tests/unit/onboarding_gate_arc_tag_fp.bats 2>&1); echo "$out" | grep -q '^ok 12 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/check_onboarding_gate.bats tests/unit/onboarding_gate_owner_human_exempt.bats tests/unit/t2815_onboarding_e2e_reachable.bats 2>&1); echo "$out" | grep -q '^ok 16 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/drift_gate_not_shadowed_by_safelist.bats tests/unit/focus_drift_gate.bats 2>&1); echo "$out" | grep -q '^ok ' && ! echo "$out" | grep -q '^not ok'
diff -q agents/context/check-onboarding-gate.py .agentic-framework/agents/context/check-onboarding-gate.py
diff -q agents/context/check-active-task.sh .agentic-framework/agents/context/check-active-task.sh
# Element-wise matching is present at BOTH call sites. Deliberately asserted in
# the positive direction only: both fixes QUOTE the old regex in the comment that
# explains the bug, so any "old form absent" grep either fails on its own
# documentation or needs code/prose discrimination that a grep cannot do. The
# negative direction — old form restored ⇒ defect returns — is covered properly
# by the mutation teeth in onboarding_gate_arc_tag_fp.bats, which drives the gate
# rather than reading it. Both patterns below are quote-free so `eval` cannot
# mangle them (the first draft of these lines failed on nested quoting, not on
# the code they were checking).
grep -qF '_parse_tags(_field' agents/context/check-onboarding-gate.py
grep -qF '([^]]*,)?' agents/context/check-active-task.sh

## RCA

**Symptom:** editing `.tasks/active/T-2877-*.md` to add a `### Human` AC was refused by
`check-onboarding-gate` with `Reason: human-ac-present`. T-2877 is arc-017's own Half A
task; the invariant refusing it is arc-017's own Half B.

**Root cause:** `has_onboarding_tag` asked `re.search(r"\bonboarding\b", tags)`. Both `:`
and `-` are non-word characters, so `\b` matches on either side of the substring inside
`arc:onboarding-curriculum`. Two distinct concepts share the word:

    tags: [onboarding]                  membership of the T-532 GATED SET
    tags: [arc:onboarding-curriculum]   membership of an ARC — a grouping, gates nothing

The gate conflated them, so arc membership was read as set membership.

**Why structurally allowed:** tag membership is a list operation performed as a text
search. A word-boundary regex over the raw `[a, b, c]` string cannot distinguish an element
from a substring of an element — no tightening of the boundaries fixes that class, only
parsing does. The same shortcut appears at the scan side (`^tags:.*onboarding`) in a looser
form, where it was **latent rather than observed**: `.context/working/.onboarding-complete`
on this repo short-circuits the block before any tag is read. A fresh project has no marker,
so there the false positive blocks every non-onboarding action with a list of onboarding
tasks the operator does not have.

The specific reason it could not be worked around: the documented override is an env-var
prefix (`FW_ALLOW_ONBOARDING_UNRESOLVABLE=1 <command>`), and the refusal fires on the
Write/Edit tool, which gives an agent no env surface. The only agent-reachable paths were
to mislabel the task `owner: human` or strip its arc tag — both of which corrupt the record
to satisfy a check that was wrong. Same shape as the deadlock class in G-078: the gate
refused the remedy it named.

**Prevention (distinct from the fix):**
- `tests/unit/onboarding_gate_arc_tag_fp.bats` holds BOTH directions — false positive gone
  AND true positive kept — so "stop refusing things" cannot satisfy it. One leg asserts
  against T-2877's real file, so the fix cannot be right in the abstract and wrong on the
  case that produced it.
- Scan-side legs clear `.onboarding-complete` before each probe, and one leg pins the
  marker's masking behaviour explicitly — that contamination produced a green positive
  control during development and is the reason this defect was invisible on this repo.
- Teeth by durable mutation (T-2874) with a positive control on the mutant itself.
- Not claimed as prevented: other places in the codebase that match tags by substring. Only
  the two call sites of *this* conflation were audited.

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

### 2026-08-08T19:49:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2881-onboarding-gate-false-positives-on-arc-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e43f627e
- **Timestamp:** 2026-08-08T20:03:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-08T20:02:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
