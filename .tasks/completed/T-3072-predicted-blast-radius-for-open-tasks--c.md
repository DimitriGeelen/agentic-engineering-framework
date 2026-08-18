---
id: T-3072
name: "Predicted blast radius for open tasks — can the cost axis be made real before
  work-completed"
description: >
  Inception: Predicted blast radius for open tasks — can the cost axis be made real
  before work-completed

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-18T09:20:41Z
last_update: '2026-08-18T09:30:06Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-18T09:22:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-18T09:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=302,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3072: Predicted blast radius for open tasks — can the cost axis be made real before work-completed

## Problem Statement

The operator's standing instruction is *"focus on HV/LC & HV/HC tasks and run BVP
estimator regularly"*. Today that instruction cannot be followed, and the tool says
so out loud:

```
NOTE: 115/141 task(s) (82%) have no known cost — blast_radius unmeasured, so no
      quadrant (COST/QUAD show '-').
```

T-3068 made the instrument honest — *unmeasured* no longer reads as *cheapest*,
which had inverted the signal. It deliberately stopped there, and named the second
half in its own Scope Fence:

> deriving blast radius for open tasks (from the fabric, from a task's own commits,
> or by populating `components:` before close) is the follow-up, and is a bigger
> change with its own design questions.

This inception is that follow-up. The question is narrow: **is there a signal
available *before* work-completed that predicts blast radius well enough to steer
by, and can it be presented without being mistaken for a measurement?**

The second clause is the harder one. L-589 states the trap directly: *a structural
proxy plus an inference is not a measurement, and the inference is where the error
lives*. A predicted cost that renders identically to a measured one would re-create
T-3068's failure in a new place — the operator would read a confident number and
have no way to know it was guessed.

## Assumptions

- **A-1:** Task authors name, in the task body, most of the source files the task
  will touch. *(Tested — Spike 1. Holds at 75% recall over source directories.)*
- **A-2:** A prediction that errs high is acceptable on a cost axis, because a cost
  filter that over-prices a task declines to promote it — the conservative failure.
  *(Tested — Spike 2. Over-estimates outnumber under-estimates 421:112, ~3.8:1.)*
- **A-3:** Exact agreement with the measured ladder is the wrong bar; the ladder is
  non-linear by design (its own docstring: *"a component count of 7 vs 8 is rarely
  meaningful, but 1 vs 5+ is"*), so within-one-rung is the meaningful metric.
  *(Argued, not measured — see IW-3.)*

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Is there any pre-close signal that predicts blast radius at all, or is
  `components:` genuinely the only thing that knows?**
  confidence: 3
  disposition: answered
  rationale: Spike 1 (docs/reports/T-3072-predicted-blast-radius.md §3) — 129 of 141
  open tasks (91%) name at least one existing repo path in their body; median 3
  paths. The signal exists and is near-universal.

- **IW-2: How close is the body-path proxy to the truth, measured against tasks
  where the truth is known?**
  confidence: 3
  disposition: answered
  rationale: Spike 2 (docs/reports/T-3072-predicted-blast-radius.md §4, three-variant
  table) over 985 completed tasks holding real `components:` — recall 0.75, precision
  0.50, ladder agreement 36% exact / 82% within-one-rung, biased high 421:112.
  Source-directory scoping is what lifts recall from 0.50 to 0.75.

- **IW-3: Is 36% exact / 82% within-one-rung good enough to steer by?**
  confidence: 2
  disposition: answered
  rationale: Argued in docs/reports/T-3072-predicted-blast-radius.md §6 (asymmetry of
  the two error directions), against T-3068's origin finding. Against the status quo
  the comparison is not 82% vs 100%, it is 82% vs
  *nothing at all* for 82% of the ranked corpus. The bias direction decides it: a
  proxy that over-prices declines to promote, which is the failure the operator can
  see and correct. Confidence 2 not 3 — this is a judgement about acceptable error,
  and it is the one the operator should overturn if they disagree.

- **IW-4: Can a predicted cost be shown alongside a measured one without the two
  being confused?**
  confidence: 2
  disposition: answered
  rationale: `compute_cost` already returns a source alongside the three terms
  (lib/bvp.sh:245) and `fw bvp`'s SOURCE column already renders one, so the seam
  exists; see also docs/reports/T-3072-predicted-blast-radius.md §7 clause 2.
  The design commitment (Scope Fence) is that predicted rows must be *visibly*
  distinct in every surface that shows a
  cost, and that the NOTE line must report the predicted/measured split rather than
  disappearing once the unknown count drops. Unverified until built — this is the
  clause most likely to be got wrong, which is why it is an AC and not a detail.

- **IW-5: Should the fabric's dependency graph be used instead of a raw path
  count?**
  confidence: 1
  disposition: deferred
  rationale: The fabric knows real downstream edges (`fw fabric impact`), which is
  a truer blast radius than "how many files are named". Deferred deliberately: it
  changes the *definition* of the axis, not just its availability, and would make
  predicted and measured values incomparable. Revisit once predicted-vs-measured
  has been observed on live rankings.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

Both spikes are complete; artefact: `docs/reports/T-3072-predicted-blast-radius.md`.

- **Spike 1 (done) — does the signal exist?** Scan every open task body for
  repo-relative paths that resolve to real files. Result: 91% coverage.
- **Spike 2 (done) — is the signal any good?** Take the 985 completed tasks whose
  `components:` was resolved from git history at close, re-derive a prediction from
  the body alone, and compare. Result: recall 0.75 / precision 0.50 / 82%
  within-one-rung / biased high 3.8:1.
- **Spike 3 (not run, deferred with IW-5)** — fabric-edge weighting.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN** — deciding whether a *predicted* blast radius should exist for open tasks,
on what evidence, and under what labelling constraints. The measurements that
answer that (Spikes 1 and 2) are done and are the substance of this task.

**OUT, and deliberately so:**

- **Changing what blast radius means.** The ladder stays the ladder (IW-5). A
  fabric-edge definition may well be better, but a predicted value must be
  comparable to the measured values already in frontmatter, and redefining the axis
  in the same change would make the two incomparable.
- **Touching `bvp_scores:`.** That is the Sovereignty boundary (M3, T-1924). This
  is the cost axis only.
- **Auto-promotion behaviour.** `fw bvp auto-promote` filters on `cost ≤ cost_max`;
  giving 82% of the corpus a cost for the first time changes what it selects.
  Whether predicted costs may drive *automatic* promotion is a separate decision
  and this task must not make it by accident — see the GO conditions below.
- **Back-filling `cost_estimate:`.** Confirmed values stay human-set. Predictions
  go to `cost_estimate_proposed:`, the existing advisory channel.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- A pre-close signal exists across essentially the whole open corpus — *met*: 91%
  of open tasks name at least one real repo path (Spike 1).
- Its error against known truth is measured, not asserted, and its bias runs in the
  conservative direction — *met*: 82% within-one-rung, over-pricing 3.8:1 (Spike 2).
- The predicted value can be carried on the existing advisory channel
  (`cost_estimate_proposed:`) without touching any confirmed or sovereignty-bound
  field — *met*: that channel already exists and already carries a `source` label.

**NO-GO if:**
- The prediction would be written into `cost_estimate:` or would render
  indistinguishably from a measured cost. This is the one that would make the
  framework *less* trustworthy than the honest silence T-3068 bought, and it is
  why "label it" is an acceptance criterion rather than an implementation note.
- The build slice would silently change `fw bvp auto-promote`'s selections.
  Predicted costs must not drive automatic promotion in the same change that
  introduces them; if the split cannot be held, the answer is NO-GO.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.
#
# Inception verification is thin by design — there is no code to compile. What is
# checked is that the artefact exists, that it still carries the measurements the
# recommendation rests on, and (the positive control) that the problem being
# explored is still live rather than already fixed by something else.
test -f docs/reports/T-3072-predicted-blast-radius.md
grep -q "129 (91%)" docs/reports/T-3072-predicted-blast-radius.md
grep -q "421 : 112" docs/reports/T-3072-predicted-blast-radius.md
# Positive control (L-616): if `fw bvp` no longer reports unknown-cost tasks, the
# premise of this inception has evaporated and the recommendation must be re-read,
# not rubber-stamped. `|| true` because the ranking's own exit code is not the
# subject here — the presence of the NOTE line is.
out=$(timeout 240 bin/fw bvp --include-proposed 2>&1 || true); echo "$out" | grep -q "have no known cost"

## Recommendation

**Recommendation:** GO — with the labelling constraint as a hard condition, not a nicety.

**Rationale:** The signal exists (91% of open tasks name a real repo path) and its
error is measured against ground truth rather than asserted (985 completed tasks
holding git-resolved `components:`). Scoped to source directories it recovers 75%
of true components and lands within one rung of the measured ladder 82% of the
time. Decisive point is not the accuracy but its *direction*: it over-prices 3.8:1,
and on a filter that prefers low cost, over-pricing means a task quietly fails to
be promoted — visible and correctable — whereas under-pricing is T-3068's inverted
signal, invisible until the cost has already been paid. Against a status quo of no
cost at all for 82% of the ranked corpus, that trade is worth making.

The condition: the prediction goes to `cost_estimate_proposed:` with an explicit
`source`, never to `cost_estimate:`, and never renders like a measured value.
A confident wrong number is harder to distrust than a blank, which is why this is
a GO/NO-GO condition rather than an implementation detail.

**Evidence:**
- Spike 1 — 129/141 open tasks (91%) name ≥1 existing repo path; median 3, max 18.
- Spike 2 — over 985 completed tasks with real `components:`: recall 0.75,
  precision 0.50, ladder 36% exact / 82% within-one-rung, bias 421 over : 112 under.
- Source-directory scoping is what earns the recall: 0.50 → 0.75 purely by not
  counting the task's own artefacts and sibling-task citations as touches.
- Full working, including the two rejected scan variants: `docs/reports/T-3072-predicted-blast-radius.md`.
- The seam already exists — `cost_estimate_proposed:` carries `source`, and
  `fw bvp` already prints a SOURCE column. No new channel is needed.

**Rationale:**

Measured over 1084 completed tasks with real components: body-named source paths recover 75% of true components at 50% precision, and agree with the blast-radius ladder within one rung 82% of the time, over-estimating 4:1 (the conservative direction for a cost filter). Status quo is no signal at all for 82% of ranked tasks, which is what makes the operator's HV/LC instruction unsteerable.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-18T09:22:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-671d1d96
- **Timestamp:** 2026-08-18T09:26:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1e01a7a8
- **Timestamp:** 2026-08-18T09:26:20Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-3072-predicted-blast-radius.md` | file | ✓ pass |
| `T-3068` | task | ✓ pass |
