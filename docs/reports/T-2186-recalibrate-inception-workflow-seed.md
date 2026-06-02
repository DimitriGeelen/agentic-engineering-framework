# T-2186 — Seed / background / reference material

**Task:** T-2186 — Recalibrate inception workflow (make inceptions first-class + prioritizable)
**Status at file creation:** started-work · horizon: now · owner: agent · type: inception
**Purpose of this file:** seed prompt the human supplied to scope this inception. Working
conclusions inside are **reconstructions to be pressure-tested**, not settled fact. Step 0
(discovery prerequisite) must be run before any conclusion is treated as ground truth.
**Note on starting status:** the task is `started-work` because the framework's P-002 gate
requires a started task to attach reference material. No research, decisions, or
deliverables have been produced yet — this file is the *initial state* of the research
artifact, per inception discipline rule C-001 ("research artifact first"). The 2-commit
inception exploration limit still applies before any `fw inception decide` can happen.

> When this inception is picked up, the agent reads THIS file in full, runs Step 0 against
> the actual framework, and works IW-1…IW-7 to dispositions-with-rationale before any
> deliverable is treated as ready-for-judge. The producer of this inception is NOT the
> judge — a separate entity (peer agent or human, scaling with stakes) confirms the
> rationales. The decision (`go` / `no-go` / `defer`) is Sovereign — human only.

---

## Agent orientation — read before anything else

You are an AEF primary agent running an **inception**. Your job in an inception is
**not to build** — it is to reduce uncertainty until the work is ready to be judged,
then hand a justified result to a separate scorer and to a human decider. Internalise
four things before you start:

1. **You operate under the authority model.** You hold **Initiative**: you propose,
   investigate, draft, and recommend. The framework holds **Authority**: it enforces
   gates and contracts. The human holds **Sovereignty**: they decide. You never
   self-authorise a Sovereign act (governance edits, `decide go`, abandoning oversight).
   When in doubt about which lane an action sits in, surface it rather than assume it.

2. **You are the producer here, so you are NOT the judge.** Anything you conclude or
   score is provisional until an entity separate from you evaluates it. Do not grade
   your own rationale. Do not declare your own discovery "sufficient." Your task is to
   make the result *inspectable* — cite evidence, name what you didn't resolve — so a
   separate judge can verify it. This is the exact principle the inception you are
   running is about; embody it.

3. **Honesty about uncertainty is rewarded, not penalised.** This is research. "I
   investigated X and the answer is genuinely open / smaller than hoped / a no-go" is
   a successful outcome, not a failure. Do not manufacture certainty or a favourable
   conclusion to look productive — that is the single behaviour most corrosive to this
   work. A confident wrong answer is worse than an honest open one.

4. **Discover before you decide, and verify before you trust.** Treat every working
   conclusion in this prompt as a reconstruction to be checked against ground truth
   (the real docs and runtime), not as fact. Do Step 0 first. If something in this
   prompt contradicts what you find in the actual framework, the framework wins —
   flag the contradiction, don't paper over it.

How to proceed: read this whole prompt, do Step 0 (discovery prerequisite), then work
the declared open questions to a disposition-with-rationale each, produce the
deliverables, and stop at `decide go/no-go/defer` — which is the human's call, not
yours. Record decisions as you go in the framework's decision format
(chose / rejected / why / decided-by / reversibility).

---

# Research Inception Prompt — Recalibrating the Inception Workflow

**Workflow type:** inception — **research/discovery** (the *direction* is known;
the *mechanics* are genuinely open. Score by value-of-information, not output value.)
**Hand this to:** a primary agent.
**Self-referential note:** this is an inception about how inceptions should be
scored and gated. It MUST run under the very rules it proposes — declare its open
questions at the start, pass its own disposition-with-rationale gate, and be scored
by a separate entity. That dogfooding is the cleanest possible validation; if the
inception's own rules are unworkable on the inception itself, that is a finding.

---

## The seed (the actual subject)

Originating question: **how do we prioritize inceptions against each other** — and
what does the inception workflow have to become to make that possible?

Today prioritization is horizon-based (now/next/later) and arc-focus-based; neither
ranks inceptions against each other. Worse, an inception is a `workflow_type:
inception` that the task estimator scores *as if it were a build task* — which
mis-scores it badly: an inception has near-floor cost (low blast_radius, low tier,
low effort) and weak direct directive support (it decides *how* a downstream thing
will help D1-D4; it does not itself harden anything). Low value + low cost lands it
in the LV/LC "trivial" quadrant — exactly backwards, since inceptions are among the
highest-leverage moves the framework makes.

This inception recalibrates the workflow so inceptions become first-class and
prioritizable. The producer≠judge *principle* this surfaces is referenced here as
what the scoring gate embodies, but its **governance elevation is OUT OF SCOPE** —
it governs all scoring, not just inceptions, and is handled as a separate proposal
(see `producer-not-judge-governance-inception-prompt.md`). This inception consumes
the principle; it does not legislate it.

## The design as it currently stands (from prior reasoning — to be confirmed, sharpened, or refuted by this inception, not assumed correct)

These are the working conclusions to pressure-test, not settled fact:

1. **Inception value is anticipatory, not intrinsic.** Score by value-of-
   information — *reach* (how much downstream work the outcome shapes), *genuineness
   of the uncertainty* resolved, and *cost-of-being-wrong* if you skipped it — not
   by the value of the (often unknown) output.
2. **`blast_radius` and `tier` flip sides for inceptions.** On build tasks they are
   cost signals; on inceptions they are *value/risk* signals — the wide-blast,
   high-tier thing is precisely what most warrants a discovery pass first. The
   recalibration may be "re-read existing primitives," not "add new ones."
3. **Arc-anchored inceptions inherit** their arc's global-driver BVP (Model B —
   independent global scoring, coherence as diagnostic, NOT child aggregation, which
   was rejected because cramming tasks would inflate value). **Orphan/discovery
   inceptions** score by VoI directly. No circularity: the arc is scored from its
   headline mechanic before constituent tasks exist.
4. **No new ceremony, no new "kind".** A separate ceremony muddles sharpness and
   leaks context at handover; declaring decision-vs-discovery *kind* at creation
   freezes a variable meant to move (an inception often starts discovery and becomes
   decision). Instead: **extend the inception workflow's status with a scoring gate
   inside the one workflow.** Decision-vs-discovery then re-emerges as *outcomes of
   the same path*, not types declared up front.
5. **The gate mechanics:**
   - The transition is **triggered by the agent completing the discovery work** —
     earned by reduced uncertainty, not fired on a timer.
   - The gate's **input is the research artefact, not the frontmatter** — or scoring
     is blind to the very discovery that justified the transition.
   - The state is **named for the epistemic condition** ("discovery sufficient /
     ready to be judged"), NOT for the calculation (`bvp-estimation`), so the name
     doesn't pre-commit the state to one mechanism.
   - After the gate the workflow **forks**: straight to build-task creation when
     clarity is high; or **parks in an investment-decision state** (Sovereign
     go / no-go / defer) when stakes are high.
6. **The gate condition is dispositions, not answers.** Each open question
   **declared at inception start** (cheap and honest while uncertainty is high) must
   reach a **disposition with a verifiable rationale** — never a binary "answered,"
   because "yes" satisfies a binary check while citing nothing. This is the §ACD
   evidence-or-justified-absence discipline. Valid dispositions: *answered* (with
   evidence), *deferred* (with reason + follow-up), *dissolved* (question was
   malformed). The start-declared questions ARE the mid-workflow gate condition —
   the two ends of the workflow stitch together.
7. **Judgment is separate, and scrutiny scales with stakes.** Rationale-quality
   can't be self-certified or reduced to a predicate, so a **separate entity scores
   and judges** (producer ≠ judge — constitutive, not optional). Scorer ≠ decider;
   the decision stays Sovereign. Depth of scrutiny scales with cost-of-being-wrong:
   positional independence (a peer agent) for routine cases; epistemic independence
   (a human reviewing the rationale) for novel high-stakes ones where the *rubric
   itself* might be wrong.
8. **`work-started` → `discovery-started` rename.** The current opening-state name
   is build-task vocabulary that lies about the epistemic activity — and that lie is
   what mis-scores inceptions. The rename is *implementation* (system-doc + a build
   task), not principle.

## Step 0 — Discovery prerequisite (before proposing changes)

Verify the ACTUAL current inception workflow against ground truth — not against the
working conclusions above, which are reconstructions:

- The real inception lifecycle states and transitions (`010-TaskSystem`, `lib/`, the
  `fw` inception verbs). Confirm the opening state is named `work-started` (or what).
- Which transitions today have mandatory-vs-optional checks, and how that hardening
  is currently expressed — the gate proposal must fit that existing pattern.
- Where inception scoring lives today (if anywhere) in `040-ValueDrivers`, and what
  the TermLink estimator actually reads as input.
- Whether any separate-judge / confirm-by-another-entity flow already exists (BVP
  confirm, audit) so the gate *names existing practice* rather than inventing it.

## Open questions to resolve (declared at start; each needs a disposition + verifiable rationale — this inception passes its OWN gate)

- **IW-1 — VoI operationalization.** How are reach / uncertainty / cost-of-being-
  wrong actually computed or elicited? Default: reach and cost-of-being-wrong from
  the flipped `blast_radius`/`tier`; uncertainty is the one genuinely missing
  primitive. Resolve whether uncertainty is **human-set** (you know how open a
  question feels) or **estimator-inferred** (an estimator guessing its own
  confidence is a snake-eating-its-tail). Leaning human-set or structurally-proxied
  (e.g. count of unresolved declared open questions), NOT estimator self-assessed.
- **IW-2 — Inherit vs VoI routing.** Is "arc-anchored ⇒ inherit, orphan ⇒ VoI" the
  right split, or do both always combine? Confirm Model B inheritance is sound and
  non-circular against the real arc-scoring implementation.
- **IW-3 — The scoring-gate state.** What is the state called (epistemic-condition
  naming, IW per #5), what is its precondition (research artefact exists at a known
  path satisfying an I/O contract), and what exactly trips the transition?
- **IW-4 — The fork & the park state.** Confirm the post-gate fork (direct-to-
  build-tasks vs park-for-investment-decision). Default: include the **investment-
  decision park state** as a real Sovereign-held state an inception can rest in with
  its VoI score attached. Resolve what routes an inception to the park vs straight
  through (default: stakes — high blast_radius/tier ⇒ park; else proceed).
- **IW-5 — Disposition gate adjudication.** Who confirms each disposition's rationale
  is verifiable, and how does scrutiny scale (peer-agent vs human) by stakes? Guard
  the *reverse* trap: what stops premature "discovery done"? Default: the gate
  refuses until each start-declared question has a recorded disposition whose
  rationale points at inspectable evidence; a separate entity confirms; human review
  triggered at high tier.
- **IW-6 — 040 ↔ inception-doc ownership seam.** Which doc owns what, to prevent
  drift? Default: 040 owns the scoring math; the inception system doc owns lifecycle
  placement and *references* 040. One doc owns each fact.
- **IW-7 — Documentation home (taxonomy / Sovereignty call — recommend, human
  decides).** Own numbered system doc (peer to 010/012) or a section of 010? Leaning
  own-doc (inception is different in *kind* from task execution — discovery vs doing;
  burying it in TaskSystem repeats the category error the rename fixes), but present
  both.

## Deliverables

- [ ] **Discovery note** — Step-0 findings + IW-1…IW-7 dispositions, each with
      verifiable rationale (chose / rejected / why / decided-by / reversibility).
- [ ] **Recalibrated inception lifecycle spec** — states (incl. the rename and the
      scoring-gate state and the park state), transition conditions stated as
      *contracts tightly, judgments by adjudicator+authority* (never a judgment
      dressed as a predicate), and the post-gate fork.
- [ ] **Inception prioritization mechanism** — the VoI scoring, inherit-vs-VoI
      routing, and the `blast_radius`/`tier` sign-flip, as a proposal slotting into
      040 (math) + the inception doc (placement), with the ownership seam drawn.
- [ ] **Documentation recommendation** for IW-7 (own-doc vs 010-section, both cases).
- [ ] **Constituent build-task slices** as runnable `fw task create` invocations
      (e.g. the rename, the gate-state machinery, the estimator change, the doc) —
      filed only after `decide go`, each sized.
- [ ] `decide go` / `no-go` / `defer` recorded.

## Constraints (non-negotiable)

- **Dogfood:** this inception runs under its own proposed rules. Its output is judged
  by an entity separate from the producing agent; the gate-disposition discipline
  applies to IW-1…IW-7 themselves.
- **Producer ≠ judge** is consumed as a given here; do NOT re-legislate it or propose
  governance edits — that is the separate spin-out's job.
- **Principle vs implementation:** the lifecycle, states, rename, gate are mutable
  implementation. Mark them so. Nothing here is constitutional.
- **No new ceremony, no new declared "kind"** (#4). If the proposal drifts toward
  either, that is a regression against a decision already made.
- **Judgments are never written as mechanical predicates.** "Is discovery
  sufficient" / "is the rationale good" are documented by *who adjudicates against
  what*, not as checkboxes — a checkbox a "yes" can satisfy is theatre.
- **Research is not authorization.** No build tasks before `decide go`.

## Scoring note (for the separate estimator — NOT the producing agent)

Score by value-of-information: reach (this reshapes how *every* inception is
prioritized and trusted), genuine openness of the mechanics, cost-of-being-wrong
(it touches the scoring layer and the workflow state machine). Do not penalise low
confidence in the eventual conclusion — that low confidence is why the discovery is
worth funding. Read the discovery note as input; do not score from frontmatter alone.

## First line of the discovery note on delivery

`Research inception: recalibrate inception workflow. IW-1…7 disposed. Scoring: VoI + blast/tier flip. Gate state: <name>. Park state: <in|out>. Inception-doc: <own|010-section>. Verdict: <go|no-go|defer>.`

---

# Step 0 Findings (2026-06-02, S-2026-0602-2308+)

Producer: agent (T-2186 session); NOT JUDGED YET. Cited inline so a separate
entity can verify. Findings refute or sharpen three of the seed's working
conclusions and confirm a fourth.

### F0.1 — State name is `started-work`, NOT `work-started`

Verified by Explore-agent read across `lib/inception.sh`,
`agents/task-create/update-task.sh`, and `policy/value-drivers.yaml` references.
The canonical state name is `started-work` (hyphen between, not "work-started").
The seed's "work-started → discovery-started rename" proposal (working
conclusion #8) is built on **non-existent terminology** — the state it names
doesn't exist.

**Disposition impact:** A8 is **refuted on terminology**, but the underlying
concern ("the opening state's name should signal epistemic activity, not
build-doing") may still be valid. If pursued, the implementation would be
adding a *new* state, not renaming an existing one. Carry to IW work.

### F0.2 — Same 4-state lifecycle for ALL workflow types

Inceptions traverse the same `captured → started-work → work-completed |
issues` lifecycle as build / test / refactor / specification / design /
decommission tasks. There is no inception-specific state machine.

**Disposition impact:** "Extend the inception workflow's status with a scoring
gate inside the one workflow" (#4) needs to be more specific: the gate has to
slot somewhere in the shared lifecycle, not in an inception-only state.
The most fitting hook is the `--status work-completed` verb-gate (see F0.8).

### F0.3 — Inceptions differ at the *decision gate*, not in state names

Inception-specific mechanics:
- `fw inception decide` is mandatory before completion (`lib/inception.sh`)
- Under `$CLAUDECODE=1`, the decide verb refuses (agent locked out, human
  Watchtower or `--i-am-human` for scripts) — `lib/inception.sh:106`, `:423`
- Filing-time `--recommendation` is required when filed under `$CLAUDECODE=1`
  (T-1715) — agent gives a recommendation BUT cannot self-authorise GO
- 2-commit exploration limit before decision is forced (commit-msg hook)
- Other workflow types have NONE of these

**Disposition impact:** The "producer ≠ judge" principle is ALREADY deployed
in inception flow — just at the decision layer, not the scoring layer.
The seed's claim that the principle needs to be added is wrong; the principle
is already there. What's missing is its *consistent application* to the
scoring/prioritization step.

### F0.4 — Cost-tier IS workflow-aware (refutes seed's premise on tier)

`agents/termlink/bvp-estimator/estimator.py:531`:
```python
COST_WORKFLOW_TIER = {
    "inception": 4, "specification": 4, "design": 3,
    "build": 2, "refactor": 3, "test": 1, "decommission": 2,
}
```

The estimator already assigns inceptions tier=4 (high), used in the cost
composite `0.6×blast_radius + 0.3×tier + 0.1×effort`. So **tier raises
inception cost, not lowers it** — the seed's working conclusion #2
("blast_radius and tier flip sides for inceptions") is **partially refuted
on tier**: tier already costs MORE for inceptions, not less.

**Disposition impact:** The sign-flip proposal needs to be re-examined per
primitive separately. Tier is NOT the culprit. Blast_radius is — see F0.5.

### F0.5 — The real estimator pathology: `blast_radius=0` structural floor

`estimator.py:537` scores blast_radius as `len(fm["components"])` mapped onto
a 0/1/3/5/7/9 ladder. Inceptions structurally have empty `components:`
because the components-to-be-touched are decided by the *post-decide* build
slices, not at inception filing time. So:

- Every inception → `blast_radius=0` (or near-zero)
- Cost composite weights blast_radius at 0.6 → dominates the formula
- Result: even though tier=4 (inception default), cost composite stays low
  because `0.6×0 + 0.3×4 + 0.1×effort ≈ 1.2 + small` → still LV/LC quadrant

**Verified on T-2186 itself:** components=[] → blast_radius=0; tier=4 (inception);
effort=small. Estimator-proposed cost ≈ 1.2. Value side: D1=2 (learning-ref),
D2=0, D3=0, D4=2 (env-class), F-RECALL=0, F-ORCH=0. Weighted BVP =
`2×9 + 0×7 + 0×5 + 2×3 + 0×6 + 0×5 = 24 / 175 max = 14%`. **LV/LC confirmed.**

**Disposition impact:** Seed working conclusion (LV/LC clustering) is right
in practice, but the mechanism is more specific than the seed names. The
fix is one of:
- (a) Make inceptions declare an *imagined target blast* at filing (human-set proxy)
- (b) Inherit blast_radius from the arc anchor (Model B in seed #3)
- (c) Estimator parses Scope Fence "IN scope:" entries as proxy components

### F0.6 — Value drivers are *mechanism-rewarding*, not *anticipation-rewarding*

Read `policy/value-drivers.yaml` rubrics for D1-D4 + F-RECALL + F-ORCH:

- D1 (antifragility) rewards healing-loop mechanisms, structural gates,
  PreToolUse hooks, regression tests — *built things*, not decisions about
  what to build
- D2 (reliability) rewards observability, audit, no-silent-failures — built
- D3 (usability) rewards human-in-loop ergonomics — built
- D4 (portability) rewards file-based, source-controlled state — built
- F-RECALL rewards reusable knowledge artifacts retrievable by `fw recall` — built
- F-ORCH rewards "routable surface" — built

**An inception ships none of these** at the time it's scored — it decides
HOW a future build slice will. So the value side floors at the few signals
the rubrics catch incidentally (e.g. body mentions an L-NNN learning, body
notes a sovereignty boundary class). T-2186's 14% is typical, not anomalous.

**Disposition impact:** The seed's working conclusion #1 ("inception value
is anticipatory, not intrinsic") is **strongly supported by direct rubric
reading**. The drivers literally cannot score discovery work fairly because
their rubrics measure outputs, not value-of-information.

### F0.7 — "Producer ≠ judge" is widely deployed, just not named

Existing patterns:
- **Decide-layer:** `fw inception decide` and `fw arc close` refuse under
  `$CLAUDECODE=1` (`lib/inception.sh:106`, `:423`; analogous in `lib/arc.sh`)
- **Scoring-layer:** `fw bvp confirm` is §ACD-gated, requires `--i-am-human`
  for scripts (T-1924 — `lib/bvp.sh`)
- **AC-layer:** Reviewer auto-tick (T-1985) — static-scan layer separate
  from producing agent, conjunctive 5-condition gate, feedback-stream rail
  for human override (`lib/reviewer/static_scan.py`)
- **AC-prefix ladder (T-1811):** `[RUBBER-STAMP]` (shell judge) → `[REVIEWER]`
  (static-scan judge) → `[REVIEW]` (human judge). Scrutiny scales with stakes.

**Disposition impact:** Seed working conclusion #7 ("a separate entity scores
and judges") is right but **already broadly implemented**. The seed should
*reuse* these patterns, not invent new ones. The "scoring gate" proposal
slots into the existing reviewer-agent + bvp-confirm layer cleanly.

### F0.8 — Dominant gate-hardening pattern: verb-gate in `update-task.sh`

Confirmed by Explore-agent: 10 structured checks fire during
`fw task update --status work-completed`, each with `--skip-<name>` flag +
matching `FW_SKIP_*` env var, logged to `.context/working/.gate-bypass-log.yaml`.
Producer/consumer parity required (T-1890).

**Disposition impact:** A new "scoring gate" should slot into update-task.sh
as one more verb-gate check, NOT as a new PreToolUse hook (which would
double-fire on every Write/Edit). Bypass mechanism: `--skip-scoring-gate
"rationale"` + `FW_SKIP_SCORING_GATE=1`, logged identically.

### Step 0 verdict on the seed's 8 working conclusions

| # | Working conclusion | Status |
|---|---|---|
| 1 | Inception value is anticipatory (VoI), not intrinsic | **CONFIRMED** by direct rubric reading (F0.6) |
| 2 | `blast_radius` and `tier` flip sides for inceptions | **PARTIALLY REFUTED** — tier already costs MORE; blast_radius is the real culprit (F0.4 + F0.5) |
| 3 | Arc-anchored inherit; orphan score by VoI | Step 0 confirms the mechanism is viable but not yet verified against `lib/arc.sh` — carry to IW-2 |
| 4 | No new ceremony, no new "kind"; extend the workflow | **SUPPORTED** but needs specificity — must slot in shared 4-state lifecycle (F0.2) at the verb-gate layer (F0.8) |
| 5 | Gate mechanics (input = artefact, name = epistemic) | Carry to IW-3 |
| 6 | Gate is dispositions, not predicates | Strongly supported by §ACD precedent — carry to IW-5 |
| 7 | Producer ≠ judge with scrutiny-scaling | **CONFIRMED ALREADY DEPLOYED** (F0.7); seed should reuse existing patterns, not invent |
| 8 | `work-started` → `discovery-started` rename | **REFUTED ON TERMINOLOGY** (F0.1); the state is `started-work`. A new opening-state, if needed, is additive — not a rename |

### Step 0 → IW handoff

The seed's premise — that inceptions are mis-prioritized — is **confirmed**.
The seed's *mechanism explanation* — that tier and blast_radius both treat
inceptions as cost-low — is **wrong on tier, right on blast_radius**. The
seed's *prescription* — VoI scoring, sign-flip on cost primitives — is
**partly viable**: blast_radius is the actual pathology; tier is fine; the
fix should target the blast_radius=0 structural floor and the rubric-mechanism
floor on the value side.

Carry to IW work:
- **IW-1 (VoI op):** Reach + cost-of-being-wrong proxies from blast_radius;
  uncertainty needs new primitive (likely human-set at filing — declared
  open-question count is a tempting structural proxy but invites gaming)
- **IW-2 (Inherit vs VoI):** Test Model B against actual `lib/arc.sh` BVP
  computation; confirm non-circularity
- **IW-3 (Gate state):** Reuse the verb-gate in update-task.sh; name the
  precondition (research artifact path + dispositions-with-rationale present);
  do NOT add a new lifecycle state — gate fires on `--status work-completed`
- **IW-4 (Park state):** Likely yes, given DEFER already parks (lifecycle
  agent finding); confirm DEFER+horizon:later IS the existing park
- **IW-5 (Adjudication):** Reuse `[REVIEWER]` for low-stakes, `[REVIEW]` for
  high-stakes, bvp confirm pattern for scoring
- **IW-6 (040 ↔ inception doc ownership):** 040 owns scoring rubrics, the
  inception doc owns lifecycle placement — confirmed by reading 040's own
  filing-history comment block (it explicitly defers lifecycle to caller)
- **IW-7 (Doc home):** Carry — Sovereignty call, human decides

---

# Dialogue Log

### 2026-06-02 — Inception start, Step 0 boundary

**Operator:** "please start work on inception"

**Agent:** Started T-2186, stated inception discipline rules, ran Step 0
in 4 parallel Explore agents (2 landed before dispatch-2 cap; remaining
2 threads run inline via Read/Grep).

**Findings produced (Step 0 section above).** Three of the seed's eight
working conclusions need sharpening (#2, #7, #8). One (#1) strongly
confirmed by direct rubric reading.

**Pending operator input:** whether to proceed with IW-1…7 dispositions in
this session or pause for course-correction on the Step 0 refutations
(especially the A8 rename — the proposed rename is built on non-existent
terminology; the underlying *concern* could still be valid but the
prescription needs reframing).

