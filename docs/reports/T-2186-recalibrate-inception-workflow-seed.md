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
