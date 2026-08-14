# BVP Driver Session — Failure Modes

Anti-patterns that the bundle exists to prevent. Most of these came from the design dialogue in `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6, where the agent (or the operator) caught a slip before it shipped. Capturing them here so future sessions catch the same slips faster.

Each failure mode has a name, a description, a recognition cue (how to spot it mid-session), and a counter-move (what to do when you recognise it).

## Driver inflation

**Description:** proposing 2–3 candidates when the project state doesn't justify them. The discovery scan finds something, but nothing distinguishing — and you propose anyway because "the verb expects candidates".

**Recognition cues:**

- Two of your three candidates have rationales that read the same when paraphrased
- You're reaching for second-order patterns ("usability of debugging tooling") because the first-order ones overlap with directives
- The operator's first response is "these all feel pretty similar"

**Counter-move:** recommend `--none` with a one-line justification. Zero approved drivers is a valid outcome. The discipline rule (rephrased verbatim from `bvp-driver-session.md`):

> Manufacturing drivers to look thorough is worse than proposing zero and recommending --none.

When in doubt, propose one strong candidate and one weak one, naming the weak one as weak — give the operator a chance to confirm "yeah, just the strong one" without the false-thoroughness signal.

## Overlap with directives

**Description:** the proposed driver is really just D1, D2, D3, or D4 said differently. R1 (differentiation) didn't converge because the candidate doesn't actually distinguish anything new.

**Recognition cues:**

- R1's answer paraphrases to "this is about reliability" / "antifragility" / "usability" / "portability"
- You can't articulate a task that scores high on the new driver AND low on the closest directive
- The candidate's name overlaps semantically with a directive's name (e.g. "robustness" vs Antifragility)

**Counter-move:** surface the overlap explicitly:

```
Agent: "I'm having trouble distinguishing <name> from D2 Reliability. Can you give me a task that would score high on <name> AND low on D2?"
```

If the operator can: drill harder, sharpen R1, this is a real distinction.
If the operator can't: kill the candidate. Either it's a sharpening of D2 (which means edit the D2 rubric, not add a new driver) or it's not a real driver.

## Manufactured drivers

**Description:** proposing a driver because the project "should have" one for cosmetic reasons, not because the work would actually score differently with it.

**Recognition cues:**

- The driver was suggested mid-session when the operator pushed back on candidate count ("can you suggest more?")
- You proposed something generic like "team-velocity" or "operational-overhead" without it being anchored in observed project state
- The driver's scoring rubric (O4) is hard to write because there's no real signal to score against

**Counter-move:** withdraw the candidate. State the withdrawal:

```
Agent: "On reflection, <name> doesn't anchor to anything I can see in the project state. Withdrawing the candidate. The two remaining are <X> and <Y>; if neither fits, recommend --none."
```

Withdrawing in-session is signal that the discipline is working, not failure.

## Single-axis routing (audience blindness)

**Description:** routing AC subject by subjectivity alone, without checking who the answer is FOR. Inherited from CLAUDE.md §AC routing ladder; applies to driver sessions because driver rationales sometimes end up in operator-facing artefacts and sometimes in agent-facing scoring.

**Recognition cues:**

- You're writing operator-facing prose ("clear and intuitive") into a driver rationale that the BVP estimator will read
- You're writing agent-facing prose ("structural, gate-enforced") into a driver name the operator will see on every backlog view
- The audience for the artefact and the audience for the driver itself diverge

**Counter-move:** rewrite for the right audience. Driver names + scoring rubric levels are read by both operator (when reviewing backlog) and estimator agents (when scoring); use language that works for both — concrete, observable, not stylistic.

See CLAUDE.md §AC Classification Guidance T-2143 for the broader pattern.

## Skipped dialogue capture

**Description:** writing the artefact's structured sections (spec, decisions ledger) but skipping or summarising §4 (sharpening dialogue). Loses the reasoning trail that distinguishes the artefact from the spec.

**Recognition cues:**

- Your §4 reads "operator agreed weight should be 5 because of usability concerns" instead of the actual back-and-forth
- §4 contains zero `[CONVERGED]:` / `[SKIPPED]:` / `[REJECTED]:` markers
- You can't reconstruct *why* a decision was made from §4 alone — only *what* was decided

**Counter-move:** rewrite §4 with the dialogue verbatim or near-verbatim. The dialogue log is the artefact's primary value over the spec; without it, the artefact is a spec with extra prose.

**Origin:** this failure pattern is captured load-bearingly in `INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6.4.11 "the double correction". The agent described HOW to capture dialogue without actually capturing it. The operator's response (verbatim): "BAD AGENT SHAME ON YOU." That's the canonical recognition memory.

## Death-marching sharpening

**Description:** drilling a single dimension past three rounds without convergence, in pursuit of a "perfect" spec. Destroys operator interpretive bandwidth; produces over-engineered drivers nobody uses.

**Recognition cues:**

- You've asked the same question three different ways and the operator's answers are getting shorter
- The operator says "just put something reasonable" or "I don't care, ship it"
- You're proposing concrete examples and the operator is responding with abstractions

**Counter-move:** skip-when-stuck. Write what you have, mark the dimension `[OPEN]`, move on. The artefact records the unresolved question; the operator can iterate via `fw bvp driver edit` later.

The rule is in `sharpening-subroutine.md`: "Driver sessions are not gates — they're proposals." Don't act like a gate when you're a proposal.

## Cap blindness (arc-scoped)

**Description:** proposing arc-scoped drivers with weights >6, or proposing more than 3 arc-scoped drivers per arc. Both violate structural caps; the handler will reject.

**Recognition cues:**

- You're writing `weight: 8` for an arc-scoped candidate
- You're on candidate #4 for the same arc
- The operator is approving everything without engaging with the caps

**Counter-move:** restate the cap before proposing:

```
Agent: "Reminder: arc-scoped drivers cap at weight ≤6 (not the global 9) and at 3 approved per arc. Current arc has <N> approved; this would be #<N+1>. Want to swap with an existing one, or kill this candidate?"
```

The cap exists because arc-scoped drivers compete for *within-arc* ranking attention, not global priority. More than 3 dilutes the signal; weight >6 lets arc-scoped concerns shout louder than global directives.

## Initialisation skip

**Description:** running the workflow on a project where `fw bvp driver --init` hasn't been run. Produces artefacts that reference YAML structures that don't exist yet.

**Recognition cues:**

- `policy/value-drivers.yaml` is missing or empty
- `policy/bvp-scoring-rubric.md` is missing
- The handler's auto-recompute step has nothing to write to

**Counter-move:** refuse. `bvp-driver-session.md` "Init refusal" section is the canonical text:

```
BVP is not initialised on this project. Run `fw bvp driver --init` first.
```

`fw bvp driver --init` is idempotent — running it on a partially-initialised project completes what's missing without disrupting what's there.

## Defer-as-hedge (from T-2144)

**Description:** writing the artefact's Recommendation as DEFER when the evidence is complete and you just don't want to commit. Borrowed from the inception discipline (T-2144); applies to driver sessions when the artefact concludes "consider this driver, but I'm not sure" without a clear evidence gap.

**Recognition cues:**

- §5 Decisions Ledger has multiple `D-N: load-bearing` entries
- §4 Sharpening Dialogue has 3+ `[CONVERGED]:` markers
- Yet §8 Final Spec is empty or marked "deferred to operator decision"
- The artefact has substantive rationale (>300 words) but no spec

**Counter-move:** write the spec. If R1+R2 converged with O1–O4 either drilled or honestly skipped, the spec is determined. Defer the *driver approval* (operator's call) by leaving the YAML write conditional, but don't defer the *spec itself*. The reviewer detector `defer-as-hedge` (T-2145) catches the inception-class version of this; the driver-session version is structurally identical.

## Spec-over-dialogue drift

**Description:** the spec ends up more polished than the dialogue would justify. Reads like the operator agreed cleanly to a thought-through plan when in fact the dialogue was messy and the spec is an idealisation.

**Recognition cues:**

- §4 dialogue has interruptions, course corrections, `[OPEN]` markers
- §8 Final Spec is clean prose with no `[OPEN]` references and no honest weak spots
- The scoring rubric (O4) covers all 6 levels even though §4 only drilled 0, 3, 5

**Counter-move:** mark the spec's weak spots honestly. If §4.O4 only drilled 0/3/5, write "1, 2, 4 inferred" alongside those rubric levels. The artefact's value comes from preserving the seam between dialogue and idealisation — readers should know which parts were drilled and which were polished.

## What this list does NOT cover

- **Pre-existing driver retirement.** That's `fw bvp driver retire <id>`, separate scope.
- **Weight editing of existing drivers.** That's `fw bvp driver edit <id>`, separate scope.
- **Estimator calibration.** That's `policy/bvp-scoring-rubric.md` and the TermLink estimator worker, separate scope.
- **Per-axis routing for handoff URLs.** That's CLAUDE.md §Per-class URL mapping (T-2125), separate concern.

This list will grow as future driver sessions surface failure modes. Treat it as living; promote any pattern that fires in 2+ sessions to its own subsection here.
