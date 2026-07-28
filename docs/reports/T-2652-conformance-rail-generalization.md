# T-2652: Conformance rail generalization — per-map canonical sources for the 4 unrailed corpus maps

**Status:** exploration in progress
**Created:** 2026-07-28
**Workflow:** inception (one question, one go/no-go)

## The Question

T-2621 shipped the first map-conformance rail: `tools/corpus_conformance.py`
collapses `aef-task-lifecycle`'s state-carrier nodes to transition pairs and
compares against `status-transitions.yaml`. It is green in the daily audit,
and that map is now eligible for the T-2619 graduation decision
(operator-owned).

The other four corpus maps (`aef-inception-flow`, `aef-session-lifecycle`,
`aef-dispatch-loop`, `aef-audit-cron`) have **no rail** — their provenance
blocks read "descriptive only — CLAUDE.md prose wins on conflict until the
conformance rail goes green." But the T-2621 checker cannot serve them: it is
hard-wired to one canonical source (the task-status transition table) that
only fits one map.

**The question:** what canonical enforced-source does each remaining map
conform against, how does the checker generalize (registry vs in-map pointer,
generic collapse vs per-source extractors), and which maps should *not* seek
a rail at all?

## Why now

- T-2621's Evolution log records the convention was designed single-map; the
  generalization was deliberately deferred.
- The transitional-subordinate authority stage (T-2619 cascading-detail model)
  is blocked for 4 of 5 maps solely by rail absence. If the program's endpoint
  is "maps hold detail, MD thins to principles," rail coverage is the
  critical path.
- The state-carrier convention itself came out of a pair round with 832 — the
  schema half of this question (can a map declare its own conforms-against
  source?) is designer-schema territory, i.e. 832's domain.

## Open Questions

Mirrored in the task file (canonical for the disposition gate); the reasoning
lives here.

- **IW-1: Where does the conforms-against declaration live?**
  (a) in the map itself — an `aef:meta` attribute on the process/collaboration
  element (e.g. `conformance=status-transitions`), designer-visible, travels
  with the map bytes, but requires 832-side schema awareness;
  (b) framework-side registry — e.g. `tools/conformance-registry.yaml`
  mapping `map_id → {extractor, source}`, zero schema change, but the map
  can't be read standalone to know its authority basis;
  (c) both — registry is operative, map carries an informational mirror.

- **IW-2: One generic checker with per-source extractors, or per-map bespoke
  checkers?** T-2621's carrier-collapse walk is reusable wherever "states +
  transition table" is the shape. Is that shape actually present in the other
  enforced machines, or do some need different comparison primitives
  (vocabulary-set equality, gate-inventory reachability)?

- **IW-3: Which maps have a real enforced machine worth conforming against?**
  A rail against advisory prose is theater — worse than no rail, because
  green would imply an authority the code doesn't back. Candidate per-map
  sources need an "is this actually enforced?" test before any build.

- **IW-4: What is the carrier convention for non-task-status states?**
  `aef:meta state=` currently means task status. Inception ends carry
  `state: go` / `state: closed` (decision outcomes); session-lifecycle would
  carry budget-ladder levels. Namespace the attribute (`state=decision:go`)?
  Separate attribute? Or per-extractor interpretation of the same attribute?

## Evidence — per-map source inventory

(filled during exploration: for each of the 4 maps, the candidate canonical
source, where it is enforced in code, and whether the T-2621 collapse shape
fits)

| Map | Candidate canonical source | Enforced where | Shape fits T-2621 collapse? |
|-----|---------------------------|----------------|------------------------------|
| aef-inception-flow | TBD | TBD | TBD |
| aef-session-lifecycle | TBD | TBD | TBD |
| aef-dispatch-loop | TBD | TBD | TBD |
| aef-audit-cron | TBD | TBD | TBD |

## Dialogue Log

(questions posed, answers given, course corrections — the WHY trail)

## Recommendation

DEFER (filing-time stub) — to be replaced with GO/NO-GO once the source
inventory and the 832 schema dialogue land.
