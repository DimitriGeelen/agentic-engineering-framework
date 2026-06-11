---
task: T-2344
arc: arc-011 (parallel-execution-aef)
mode: batch_propose (Workflow A)
ts: 2026-06-11T19:45:00Z
keystone: policy/prompts/bvp-driver-session.md
worked_examples: policy/prompts/bvp-references/arc-scoped-driver-examples.md
discipline_failures: policy/prompts/bvp-references/discipline-failure-modes.md
---

# T-2344 — arc-011 Workflow A driver session (retroactive)

## Context

arc-011 (`parallel-execution-aef`) was created 2026-06-10 with `proposed_scoped_drivers: []`
empty. Per CLAUDE.md §Arc-Scoped Driver Suggestion Workflow (T-1925), the 5-step protocol
should run on new-arc creation. It did not. This session runs it retroactively.

The arc's headline_mechanic (from `.context/arcs/parallel-execution-aef.yaml`):

> two agents on disjoint-write-set tasks run concurrently against shared substrate,
> integrate results through the hub's serialized integration queue, and the operator
> observes both **wire-evidence of parallelism** (two dispatch IDs in flight at once
> in dispatches.jsonl) and the **absence of governance-plane corruption** (no .tasks/
> or .context/audits/ merge conflicts) — wire-evidence-X to be sharpened by T-2303 Spike 1

The arc's M1 (single-host AEF-only) shipped 6/6 in the prior session (T-2337/T-2338/T-2339/T-2340/T-2341/T-2342). The headline_mechanic FIRED on T-2341's demo. Three M1 tasks
specifically embodied **disjoint write-set discipline** (T-2337 validator, T-2340 pre-flight gate)
or **wire-evidence capture** (T-2341 demo, T-2342 view). This pattern suggests two arc-scoped
drivers; analysis below.

## Candidates Considered

### Candidate 1 — D-DISJOINT (Disjoint Write-Set Discipline)

**Weight proposed:** 5 (heavier than D3 usability because the arc's load-bearing invariant
is disjointness; lighter than D2 because reliability bounds correctness broadly while
D-DISJOINT bounds a specific structural property).

**R1 — what this distinguishes:** Work that strengthens or weakens the arc's load-bearing
invariant (no two concurrent agents write to the same path). D-DISJOINT specifically rewards
work that (a) declares `write_set:` scope up front, (b) tests collision **pre-flight**
(structural prevention, not post-hoc audit), (c) catches the class structurally so it cannot
silently re-emerge.

**R1 differentiation test vs D2 (Reliability):** D2 would equally reward a post-hoc audit
that flags collision after the fact (the failure is *observable*, hence D2 is satisfied).
D-DISJOINT only rewards **pre-flight** discipline — refuse-the-dispatch-if-collision rather
than allow-and-detect-after. The two attitudes shape entirely different downstream tasks.
Distinct.

**R1 differentiation test vs D1 (Antifragility):** D1 rewards systems that strengthen under
stress. D-DISJOINT rewards refusal to let stress (collision) happen at all. Closer to "don't
get hit" than "shrug off the hit". Distinct, though related.

### Candidate 2 — D-WIRE-EVIDENCE (Wire-Evidence Falsifiability)

**Weight proposed:** 4 (lighter than D-DISJOINT because the invariant matters more than its
evidence; heavier than D4 portability because portability is not arc-011's concern).

**R1 — what this distinguishes:** Work that produces **captured wire artefacts**
(dispatches.jsonl excerpts, git status snapshots, timing.yaml) such that the headline_mechanic
is *falsifiable* — re-runnable evidence, not narrative claim. D-WIRE-EVIDENCE specifically
rewards capturing evidence at the moment the mechanic fires, in a form an outside party can
re-check by re-running.

**R1 differentiation test vs D2 (Reliability):** D2 covers observability broadly — a log line
or metric satisfies it. D-WIRE-EVIDENCE requires **captured, re-runnable artefacts** tied to
a specific arc claim. A log line that says "two dispatches in flight" satisfies D2 but not
D-WIRE-EVIDENCE; T-2341's `docs/reports/arc-011-m1-headline-mechanic-evidence.md` with embedded
dispatches.jsonl excerpts satisfies both. The discipline-failure-mode this driver counters is
"substrate is in place; closure is not blocked on a demo" (G-062 anti-pattern).

**R1 differentiation test vs D1 (Antifragility):** D1 rewards stress-strengthening; D-WIRE-EVIDENCE
rewards falsifiability. Falsifiability is a precondition for antifragility (you can't strengthen
what you can't measure), but the two are distinct dimensions. Distinct.

### Candidate 3 (REJECTED) — D-YIELD-CLEANLINESS (Concurrency Yield Cleanliness)

**Why rejected:** R1 produces "rewards picking the right yield granularity (§6 AEF ADR open
question)" — but the yield granularity work is M2-prep (post-M1), and even there it folds
naturally under D-DISJOINT (a yield point that prevents collision is disjointness work) or
D2 (a yield point that doesn't crash is reliability). Adding D-YIELD-CLEANLINESS would dilute
the operator's interpretive bandwidth without distinguishing tasks the existing pair don't.

**R5 discipline:** *Manufacturing drivers to look thorough is worse than proposing zero and
recommending --none.* Three would have looked thorough. Two are real.

## Final Spec

Two arc-scoped drivers proposed to `.context/arcs/parallel-execution-aef.yaml`
`proposed_scoped_drivers:`. Approval stays with the operator via
`bin/fw arc approve-driver arc-011 D-DISJOINT --weight 5` (and the same for D-WIRE-EVIDENCE),
or `bin/fw arc approve-driver arc-011 --none --justification "..."` if the operator disagrees
with the analysis.

```yaml
proposed_scoped_drivers:
  - id: D-DISJOINT
    name: Disjoint Write-Set Discipline
    weight: 5
    rationale: |
      R1: rewards pre-flight collision refusal (write-set scope declared, tested before
      dispatch) — D2 (reliability) rewards post-hoc observability of the same failure
      class but not the structural prevention. Anchors the arc's load-bearing invariant
      (headline_mechanic clause "no .tasks/ or .context/audits/ merge conflicts").
      R2: weight 5 — heavier than D3 (5) because invariant-defining, lighter than D2 (7)
      because reliability bounds correctness broadly.
    source: agent
    ts: 2026-06-11T19:45:00Z

  - id: D-WIRE-EVIDENCE
    name: Wire-Evidence Falsifiability
    weight: 4
    rationale: |
      R1: rewards captured, re-runnable wire artefacts (dispatches.jsonl excerpts, git
      status snapshots, timing.yaml) tied to a specific arc claim — D2 satisfies "log
      line says X happened", this driver requires the evidence be re-runnable by an
      outside party. Counters G-062 substrate-vs-deliverable conflation at arc-close time.
      R2: weight 4 — lighter than D-DISJOINT (the invariant matters more than its proof),
      heavier than D4 (3 — portability not arc-011's concern).
    source: agent
    ts: 2026-06-11T19:45:00Z
```

## Sharpening Dialogue

None — Workflow A (batch_propose) does NOT run the sharpening subroutine per candidate.
Proposal shape is one-line + one-line rationale (extended here for traceability since the
session is retroactive; future Workflow A runs should match the spec format above).
Sharpening (R1+R2 required; O1-O4 optional) runs in Workflows B/C if the operator picks
one of these for promotion to global free driver scope.

## Decisions Ledger

- **2026-06-11:** Proposed two arc-scoped drivers (D-DISJOINT w=5, D-WIRE-EVIDENCE w=4)
  rather than three (D-YIELD rejected per R5 discipline) or zero (--none).
- **Rationale for proposing now (retroactive):** arc-011 M1 already shipped; future M2 / IC
  work would benefit from these distinctions even though M1 didn't have them. Zero harm done
  by M1's absence (operator pre-shipped the 6 M1 tasks intentionally), but the proposal has
  forward value.

## Rejected Paths

- **3rd driver D-YIELD-CLEANLINESS:** see Candidate 3 above. R1 too close to D-DISJOINT and D2.
- **Recommend --none:** considered. Rejected because two drivers clearly distinguish member
  tasks within arc-011 (T-2337/T-2340 = D-DISJOINT, T-2341/T-2342 = D-WIRE-EVIDENCE, with
  T-2338/T-2339 mixed).
- **Higher weights (D-DISJOINT=6, D-WIRE-EVIDENCE=5):** considered. Rejected because arc-scoped
  cap is weight ≤6 per M2 and approaching cap leaves no headroom for a future third driver if
  M2 work surfaces a real new distinction.

## Operational Consequences

- **If operator approves both:** the BVP estimator will score member tasks against the two
  drivers; ranking within arc-011 will distinguish disjointness-strengthening work from
  evidence-capture work from generalist work. Auto-recompute fires per the bundle's after-action
  protocol (`fw bvp recompute --scope arc:arc-011`).
- **If operator approves one:** half-effect of the above; still useful.
- **If operator approves --none:** session closes with no YAML change beyond the proposal
  record; arc-011 falls back to global D1-D4 ranking only. Valid R5 outcome.
- **Out-of-scope:** these are arc-scoped, not global. They do NOT compete with D1-D4 for the
  9-driver global cap. They do NOT affect ranking outside arc-011.
