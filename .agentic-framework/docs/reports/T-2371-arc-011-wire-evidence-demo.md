# T-2371 — arc-011 Spike 1: wire-evidence demo (captured)

**Task:** T-2371 · **Arc:** arc-011 (parallel-execution-aef) · **Date:** 2026-06-13

## Purpose

arc-011's `headline_mechanic` originally ended *"wire-evidence-X to be sharpened by
T-2303 Spike 1"* with `demo_evidence: null`. grill_me primary_target #2 asked whether the
wire-evidence (*"two dispatch IDs in flight at once in dispatches.jsonl"* + *"absence of
governance-plane corruption"*) is **actually falsifiable**, or whether it needs *"a concrete
test scenario with named tasks and a captured dispatches.jsonl excerpt."*

This report is the answer: it is falsifiable, the concrete scenario already exists
(`agents/dispatch/single-host-parallel-demo.sh`, T-2341), and this is the captured run.

## What was discovered mid-build (L-458)

The runnable harness was **already shipped** as T-2341. Building a second one would have
duplicated it. So T-2371 became: *run it, capture the evidence, and sharpen the arc to
reference it* — not *build a new harness*. (Second redundancy caught-before-building this
session; first was OBS-072 vs the existing CTL-028 detector.)

## Captured run (verbatim)

```
$ bash agents/dispatch/single-host-parallel-demo.sh --sandbox <sandbox>
demo: sandbox = <sandbox>
demo: checking orchestrator-graph emits both as parallel...
T-DEMO-A	parallel
T-DEMO-B	parallel
demo: checking pre-flight approves both...
demo: spawning 2 workers concurrently...

=== Headline_mechanic assertions ===
✓ overlap window observed: both T-DEMO-A and T-DEMO-B in-flight simultaneously
✓ .tasks/ clean: no merge conflict markers
✓ output files exist: A.md, B.md
✓ wall-clock duration: 1s (serial would be ~2s; concurrent ~1s)

=== T-2341 single-host parallel demo: headline_mechanic FIRED ===
EXIT: 0
```

## The wire evidence: `dispatches.jsonl` (the two-in-flight excerpt)

```jsonl
{"dispatch_id":"D-DEMO-001","task_id":"T-DEMO-A","outcome":"","started_at":1781358552}
{"dispatch_id":"D-DEMO-002","task_id":"T-DEMO-B","outcome":"","started_at":1781358552}
{"dispatch_id":"D-DEMO-001","task_id":"T-DEMO-A","outcome":"success","completed_at":1781358553}
{"dispatch_id":"D-DEMO-002","task_id":"T-DEMO-B","outcome":"success","completed_at":1781358553}
```

**Reading it:** two distinct `dispatch_id`s (`D-DEMO-001`, `D-DEMO-002`) each emit a start
row with `outcome:""` at the **same** `started_at` (1781358552) — i.e. both are *in flight
at once*. Both then complete (`outcome:"success"`) at 1781358553. That co-occurrence of two
`outcome:""` rows is the operationalised, machine-readable definition of *"two dispatch IDs
in flight at once."*

## Why each predicate is falsifiable (the failing input for each)

The demo does not merely *assert success* — each predicate has a defined input that makes it
**fail**, which is what makes the wire-evidence a test rather than a slogan:

| # | Predicate | Falsifying input | Demo exit |
|---|-----------|------------------|-----------|
| 1 | Overlap window — two `outcome:""` rows share a `started_at` | Workers serialize (substrate falls back to sequential) | `1` |
| 2 | Governance plane clean — no `<<<<<<<`/`>>>>>>>` under `.tasks/` | A seeded merge-conflict marker | `2` |
| 3 | Outputs A.md + B.md exist | A worker fails to write its declared path | `4` |
| 4 | Disjointness discriminates | `fw write-set check` on a shared-glob pair | `write-set` exit `1` (`overlap`) |

### Discrimination control (verified inline)

To prove the disjointness check is not a rubber-stamp, a deliberately-**overlapping** pair
(both declaring `docs/reports/_demo/shared.md`) was checked:

```
$ PROJECT_ROOT=<ctl> python3 lib/write_set.py check T-COL-A T-COL-B
overlap
# exit 1  (disjoint pair returns `disjoint`, exit 0)
```

The same primitive returns `disjoint`/`0` for the demo's T-DEMO-A/B pair and `overlap`/`1`
for the shared-glob control — it discriminates on declared write-sets.

## Scope boundary

This sharpens the *mechanic* (Spike 1, explicitly named in the arc) using the *existing*
`fw write-set check` primitive (T-2337) and the *existing* demo (T-2341). It is independent
of the operator-parked policy inceptions T-2323 (yield-point granularity) and T-2324
(disjoint-write-set policy) — those decide *policy*; this demonstrates the *primitive*.

**Final arc close remains Sovereign (G-062).** This report + the demo's exit-0 are the
`demo_evidence` an operator can run and observe before deciding `fw arc close`.

## How an operator reproduces it

```
cd /opt/999-Agentic-Engineering-Framework && bash agents/dispatch/single-host-parallel-demo.sh
```

Exit 0 with the four ✓ assertions = the headline_mechanic fired. The demo is fully
sandboxed (`mktemp -d` or `--sandbox DIR`); it never touches the real `.tasks/` or
`.context/`.
