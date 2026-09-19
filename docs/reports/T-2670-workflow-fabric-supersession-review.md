# T-2670 — workflow fabric: queryable cross-map index (package Lock 4 / SD-15): supersession review

**Task:** T-2670 (inception, arc-014 designer-corpus)
**Question:** Should cross-map structure (handoffs, sub-process calls, lane/role
participation) be indexed into a queryable registry supporting role-level queries,
per the package's Workflow Fabric spec?
**Filed:** 2026-07-28 with `Recommendation: DEFER` — *"no concrete cross-map query
need has surfaced yet — corpus is 5 maps with 2-3 handoff pairs, walkable by eye …
Revisit evidence: first real occasion someone needs a cross-map answer and cannot
get it from the gallery."* **Reviewed:** 2026-09-19 under the T-3391 autonomous
run. Read-only research; no spikes, no build artefacts. Sibling of
`T-2668-guided-mode-supersession-review.md` (same method, same successor arc).

## 1. Has the DEFER's revisit evidence arrived? (IW-1)

**Corpus scale.** `.context/designer/projects/` holds 16 entries: 8 canonical
`aef-*` maps (audit-cron, dispatch-loop, existing-project-onboarding,
greenfield-onboarding, inception-flow, session-lifecycle, task-lifecycle,
tier0-escalation), 7 substantive drafts (arc-lifecycle, continuous-run-loop,
exception-handling, inception-readiness, knowledge-leveling, task-creation,
trigger-handling) and one scratch. Three times the July count.

**Cross-map links.** `grep -rl callActivity|calledElement|handoff` matches 10
maps (29 hits; draft-trigger-handling 7, draft-continuous-run-loop 5,
aef-dispatch-loop 4). Typed-event throw/catch bindings pair across maps (T-2604),
and `workflowRef` links exist in real corpus documents — T-2891 found that *none*
of the five `aef-bpmn` fixtures carried one, so every fidelity verdict to that
date had been measured on documents with no cross-map links, and added a real one.

**Query demand.** No task, observation or concern since 2026-07-28 asks a
role-level cross-map question (the DEFER's example: "the operator's
decision-surface across all maps"). What did appear were two **bespoke cross-map
scans**, each answering one question by walking every map:

| Surface | Question it answers | Shape |
|---|---|---|
| `tools/corpus_lint.py` cross-map pass (`emitterless-typed-event`, T-2604) | "Does any map throw the typed event this map catches?" | Scan of every map per lint run |
| `tools/corpus_explain.py --search TERM` (T-2942) | "Which maps mention X?" | Text search over the store |

Reading: the premise ("walkable by eye") is gone, and cross-map questions are
being answered — one bespoke scan at a time. That is the pattern EWCR §8.3
names as the thing a fabric exists to prevent ("must not become a third
hand-maintained copy"), arriving from the other direction: N hand-maintained
scans. But it is not yet the operator-level query demand the DEFER was waiting
for. IW-1 is answered *partially*: scale yes, demand not as specified.

## 2. arc-019 ownership (IW-2)

`docs/research/executable-workflow/architecture-c9070637.md` §8.3 *Workflow
Fabric: the process-topology join*:

> A future Workflow Fabric can be a derived, queryable graph of
> procedure/step/lane entities and flow, call, handoff, component, context, and
> inferred-dataflow relationships. It must not become a third hand-maintained copy
> of the other fabrics. … It enables the valuable cross-domain query:
> `changed component → affected technical steps → affected procedures → dependent
> procedures → affected human touchpoints`

That is T-2670's registry (handoffs, calls, lane/role participation) **and**
SD-13's component linkage, which T-2662 §4 routed "inside T-2670's fabric
question". `roadmap-5be23719.md` Arc 4 *Operator control and Workflow Fabric
projection* builds it: item 4 (projection over `ratified-latest` + live-bound
versions), item 5 (join steps to Component and Context Fabric refs), item 6
(impact queries, measured/unmeasured topology states); Arc 5 item 3 adds the
derived index and impact query for guided procedures. The operator ratified the
architecture 2026-08-20 (§18) and Arc 0 has landed (T-3385–T-3388).

Two design facts EWCR fixes that T-2670's framing left open: the index is
**derived, never authored** (§8.3), and its default projection is
version-aware (`ratified-latest` plus versions bound to live instances) —
neither existed as a constraint in the package's Lock 4.

## 3. SD-15 lineage (IW-3)

T-2662 §4: *SD-15 Workflow Fabric — routed to T-2670 (rec DEFER)*; *SD-13
Component Fabric linkage — parked, revisit inside T-2670's fabric question*.
T-2663's GO: *"the register's remaining open items (SD-3/10/13/14) inherit
dispositions from this call"* — SD-15 was not in that list because it was
already routed here. So T-2670 is the live holder of SD-15 and, by T-2662's
routing, of SD-13. Both now have an owner in arc-019 Arc 4 (items 4 and 5
respectively).

## 4. Assumption ledger

| ID | Assumption | Verdict | Evidence |
|---|---|---|---|
| A-057 | Corpus still ~5 maps, walkable by eye | **invalidated** | §1 — 16 store entries, cross-map markers in 10 |
| A-058 | A concrete operator-level cross-map query need has surfaced | **invalidated** | §1 — none filed; two bespoke scans built instead |
| A-059 | arc-019 owns the Workflow Fabric derived index | **validated** | §2 — §8.3; Arc 4 items 4–6; Arc 5 item 3 |

## 5. Go/No-Go evaluation

- **GO if** a cross-map registry is unowned and a bounded slice under arc-014 could deliver it — *not met*: owned by arc-019 Arc 4 with a ratified design (derived, version-aware) that T-2670's framing lacks.
- **NO-GO if** authorising build slices here would create a second fabric beside a ratified one — *met*.
- **DEFER if** the revisit evidence has still not arrived and no successor owns the question — *not met*: a successor owns it; continuing to DEFER would leave SD-13/SD-15 formally parked in a task whose question has moved.

## 6. Recommendation

**NO-GO — dissolved by supersession into arc-019 Arc 4.** No build slices from
T-2670. To make the decision unambiguous on the review form: **GO would mean
"build a cross-map registry under arc-014 now"; NO-GO means "T-2670's question
is owned by arc-019 Arc 4; close it as dissolved, carry the transfers below."**

Transfers to arc-019 (recorded here, not decided here):

1. **The two bespoke scans are the seed queries.** `corpus_lint`'s cross-map pass and `corpus_explain --search` are the first two consumers a derived Workflow Fabric must subsume; when Arc 4 item 4 lands, both should read the index rather than re-walk the store, or they become the hand-maintained copies §8.3 forbids.
2. **SD-13 rides with SD-15.** Component linkage is Arc 4 item 5; zero `components:` refs on any map today (T-2662) is the measured starting state.
3. **Corpus growth is the demand signal the DEFER asked for**, arriving as scale rather than as a filed question: 15 maps with cross-map links is past "walkable by eye".

Not decided here: T-2669 (audience lenses, SD-14) — no EWCR section names it;
it needs its own check and, unlike T-2668/T-2670, likely a genuine design
dialogue.

## 7. Dialogue log

None — executed under an autonomous mandate (T-3391); the go/no-go is reserved to
the operator via `fw task review T-2670`. Note from the same run: T-2668's review
form was answered **GO** while carrying the NO-GO rationale verbatim; the
recommendation wording above is written so that the two verbs cannot be read
as the same act.
