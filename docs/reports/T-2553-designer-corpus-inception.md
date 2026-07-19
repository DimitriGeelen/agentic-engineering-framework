# T-2553 — Designer corpus exercise: document the 5 most-used AEF processes in the workflow designer

**Inception.** Should we run a corpus exercise — documenting real AEF processes as BPMN diagrams in
the 832 workflow designer, pushing each through the `fw bpmn` pipeline, and accumulating every
discovered gap into a dedicated arc? Anchor of arc `designer-corpus` (arc-014).

Status: **GO recommended** — scope fully settled in a live operator grill (2026-07-19), pipeline
verified live, selection grounded in telemetry. Decision is the operator's.

---

## Context: where the integration stands (evaluated this session)

| Stage | State |
|-------|-------|
| Designer serving (`/designer`, sha-pinned bundle, nav link) | live-verified (T-2523/T-2525) |
| Gallery API (8 `/api/*` endpoints) | live, aligned to 832's 0.2.0 client (T-2529/T-2530) |
| Mapping contract (aef:uid, lane→owner, O-1, O-3 veto, flow→horizon) | built; **frozen-v1 not human-ratified** (832 T-189/T-190) |
| `fw bpmn compile` + `--write` staging | shipped (T-2531/T-2539) |
| `fw bpmn promote` (gated writer, idempotent uid+sha reconcile) | shipped+hardened (T-2542/T-2543); joint test `bpmn_promote_e2e.bats` ratified both sides (rail offsets 80/81) |
| Typed events | producer done (832 T-204); AEF WARN shipped (T-2552); consumption at operator decision (T-2551, NO-GO recommended); byte-exact fixture inbound from 832 |
| Reverse direction (AEF→BPMN export) | does not exist |

**The gap:** every proof above ran on fixtures. Zero real-world corpus. The rendered-corpus work was
previously deferred for exactly this reason ("no corpus = no substrate"). This exercise is the
corpus.

## Dialogue Log (grill, 2026-07-19)

Operator asked for evaluation of (a) integration progress, (b) readiness to document AEF workflows
in the designer, (c) whether documenting 3–5 AEF processes is a good test/iteration — and asked to
be grilled before incepting. Agent presented the evaluation above plus 7 grill questions; operator
answered:

- **Q1 (purpose): → 1c, both.** Diagrams are real documentation AND each runs the pipeline; gaps
  are logged, not fixed mid-flight.
- **Q2 (authorship): → 2d, pair.** 832 or AEF drafts; operator reviews/corrects in the designer UI.
  Tests both the pipeline and 832's actual product at bounded operator cost.
- **Q3 (success criterion): → accumulator arc.** Operator (verbatim intent): vocabulary gaps,
  issues, errors, valuable enhancements discovered, and failings are ALL added to the arc as we go;
  the arc must be driven to completion with a quality outcome. Agent reflection: this maps 1:1 onto
  the framework's arc model — constituent tasks carry `arc_id: designer-corpus`, and the arc close
  gate (G-062: `--demo` of the headline mechanic firing) makes "quality outcome" structural rather
  than aspirational. Confirmed sensible.
- **Q4 (vocabulary extension): → authorized AND instructed**, with the constraint that the workflow
  agent (832) remains owner of the development process. Operator framed continuity/fluidity of the
  vocabulary loop as the core of the exercise. Agent reflection (§4 below) — agreed: this inverts
  the original risk framing; extension is safe *because* the WARN layer + rail ratification loop
  exist, and stress-testing that loop at corpus rate is itself a primary deliverable.
- **Q5 (drift ownership): operator corrected the question** — the process owner owns drift; for
  these processes, the AEF agent. Agent accepted: no misunderstanding operator-side; the agent's
  residual point (a *structural* drift check, fabric-drift-style) is filed as an arc enhancement
  candidate, not iteration-1 scope.
- **Q6 (sequencing vs frozen-v1 and T-2551): operator asked for elaboration** — provided in §6
  below with a recommendation.
- **Q7 (process selection): operator instructed telemetry-based selection** — most used and most
  critical. Executed in §7 below; the telemetry changed the agent's initial shortlist (healing loop
  dropped for lack of usage; dispatch loop and audit cron promoted on real event mass).

## §4 — Vocabulary continuity/fluidity (the core, per operator)

The two-sided contract: AEF is the discovery side (finds what real processes need); 832 owns the
vocabulary and designer (ratifies and implements). The continuity spine already exists and has
closed the loop four times (aef:uid, lane→owner, promote seam, typed events):

1. Gap discovered while documenting → filed as arc-014 constituent task.
2. AEF proposes an **additive** extension over the rail as a tracked item.
3. 832 ratifies/implements (KNOWN_AEF_KEYS + palette) → sends byte-exact fixture.
4. AEF implements compile-side handling; joint bats pins it.

Fluidity guarantees: **additive-only** (diagrams drawn early never break), **WARN-first** (the
T-2552 pattern is the forward-compat buffer — a construct can appear in diagrams *before* its
semantics land, visibly, never silently), **versioned base** (extensions are diffs against
frozen-v1 once ratified). Rail round-trip latency is the honest constraint on cadence — measuring
it under corpus-rate load is part of the exercise.

## §5 — Drift ownership

Process owner owns keeping the diagram true — for the 5 selected processes, the AEF agent, within
the arc. Logged enhancement candidate (future arc constituent, not iteration-1): a structural drift
check where each diagram carries source refs to the lib/agents files implementing the process, and
doctor/audit WARNs when those change — same pattern as fabric drift and cron-registry drift.

## §6 — Sequencing vs the two pending operator decisions (elaboration requested)

**Frozen-v1 ratification (832's T-189/T-190).** The mapping contract is implemented both sides and
joint-tested, but has never been human-ratified as "v1 frozen". Now that vocabulary extension is
*instructed* (Q4), ratifying the base first becomes MORE valuable, not less: every extension becomes
a diff against a signed baseline instead of growth on a moving target. Cost is low (review + sign-off).
**Recommendation: ratify frozen-v1 before or at arc start.**

**T-2551 (typed-event consumption; NO-GO recommended, sitting at `/inception/T-2551`).** This corpus
exercise is exactly T-2551's revisit condition: the telemetry-selected processes are saturated with
typed-event shapes (dispatch = message, session/audit = timer, audit branches = error), so the arc
will produce *real* evidence of whether any typed event has a live consumer worth building.
**Recommendation: record NO-GO now** (keeps WARN-only, blocks nothing) **with an explicit revisit
clause** — reopen if the arc produces ≥1 diagram whose typed event maps to an identified live
consumer. Holding T-2551 open for weeks as a dangling inception is worse hygiene for the same
outcome.

## §7 — Telemetry-based process selection (operator-instructed)

Measured this session from the live corpus:

| Process | Usage telemetry | Criticality signal | Seam stress |
|---------|----------------|--------------------|-------------|
| 1. Task lifecycle (captured→started↔issues→completed) | 1599 completed + 230 active build tasks — dominant by far | Everything flows through it; P-010/P-011 gates; human-AC partial-complete | Lanes + human gate |
| 2. Inception flow (explore→GO/NO-GO→children) | 408 completed, 295 with recorded decisions, 21 active | Sovereignty boundary (agent-blocked decide) | Inception-subprocess materialization (T-2549) + decision gateway |
| 3. Session lifecycle (init→work→handover→push) | 1387 handovers | Proven incident history (memory-loss class T-2506/2507) | Timer/cron flavor |
| 4. Dispatch-orchestration loop (resolver→worker→outcome backprop) | 992 dispatches, 1240 outcome events | Autonomy substrate | Message events — exactly what T-2551 declined |
| 5. Audit cron (timer→audit→WARN/FAIL→emit) | 748 cron runs + daily audits | Silent-drift detection backbone | Timer + error branching |

Dropped from the agent's pre-telemetry shortlist: **healing loop** — only 26 issues-transitions in
the whole corpus; criticality without usage. The meta candidate (BPMN promote flow itself) is held
as an optional 6th calibration diagram, not counted in the 5.

## Candidate directions considered

- **C-A — run the exercise as scoped above (arc-accumulator, pair-draft, additive extension):**
  recommended.
- **C-B — docs-only pass first, pipeline later:** rejected by operator (1c chose both); would also
  halve the discovery value per diagram.
- **C-C — build the reverse exporter (AEF→BPMN auto-gen) first:** rejected — automates
  documentation before we know the vocabulary can express the content; the manual corpus is the
  prerequisite evidence.

## Outcome

GO recommended. On GO: `fw arc start designer-corpus`, spawn build child #1 (task lifecycle
diagram), notify 832 of the pair-drafting cadence. Operator decisions bundled at handoff: this
GO/NO-GO, frozen-v1 ratification, T-2551 decision.
