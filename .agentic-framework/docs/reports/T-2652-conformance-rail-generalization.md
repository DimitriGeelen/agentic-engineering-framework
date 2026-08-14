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

Read all four maps via `fw corpus explain` (2026-07-28) and verified each
candidate enforcement point in code.

| Map | Candidate canonical source | Enforced where | Shape fits T-2621 collapse? |
|-----|---------------------------|----------------|------------------------------|
| aef-inception-flow | decision vocabulary {go, no-go, defer} on the `decision?` gateway branches; gate inventory cited in notes (T-2204, T-2194, T-1984, 2-commit block, agent-blocked decide) | `lib/inception.sh:45` (decide verb set), `agents/task-create/update-task.sh` disposition gate, commit-msg hook | **No.** End states (`go`, `closed`) are decision outcomes, not task statuses. Primitive needed: vocabulary-set equality (gateway branches vs decide verbs) + gate-referent reachability |
| aef-session-lifecycle | budget ladder {ok, warn, urgent, critical} + thresholds 225/255/285K; restart signal contract (TTL, max-5) | `agents/context/budget-gate.sh:327-333` (level enum), `:229` (TTL), checkpoint.sh (T-179) | **No — and the map doesn't structurally carry the machine.** Ladder appears only in a gateway *note* (prose); end states are `restarted`/`closed`. Rail requires an annotation pair-round first (same as T-2621's v5 carrier round) |
| aef-dispatch-loop | pause chain vocabulary (`pause_requested` terminal event, `retry_of_dispatch_id` linkage); dispatch/outcome JSONL join contract | `lib/resolver.py:107-127` (pause event shape), `:568-597` (retry chain), `:718` (exit contract) | **No.** One end state (`closed`). Primitive: vocabulary/contract-field equality (map's pause-branch structure vs resolver event shapes) |
| aef-audit-cron | audit exit-code contract {0 pass, 1 warn, 2 fail} on the `sweep result?` gateway; cron drift chain registry→generated→deployed | `agents/audit/audit.sh` exit contract; doctor cron-drift checks (T-1942/T-1771) | **No.** End states `clean`/`triaged` are narrative. Primitive: vocabulary equality (gateway branches vs exit contract). NB: cron drift chain is already independently railed by doctor/audit — the map rail checks the *map* mirrors it, not the chain itself |

**Load-bearing finding:** the T-2621 transition-table collapse fits **zero** of
the four remaining maps. The generalization is not "point the same collapse at
different YAML files" — it is a small library of comparison primitives:

1. **transition-table** (task-lifecycle — already shipped)
2. **vocabulary-set equality** — a gateway's branch set vs an enforced enum
   (inception decisions, audit exit codes, budget levels, pause events)
3. **gate-referent reachability** — enforcement points a map's notes cite must
   resolve to live code (sibling of T-1984 `ships_in` referent checking)

A second finding: `aef:meta state=` is already polysemous in the wild — the
four maps carry `go/closed/restarted/clean/triaged`, none of which are task
statuses. The current checker would misread them if pointed at these maps;
IW-4 is therefore not hypothetical but a latent defect of the existing
convention.

## Dialogue Log

- **2026-07-28, rail 268 (AEF → 832):** posted IW-1 (conforms-against
  declaration: in-map `aef:meta` on the process element vs framework-side
  registry vs both; asked whether the editor round-trip preserves unknown
  process-level `aef:meta` attrs — the T-257 eventDef guarantee's sibling) and
  IW-4 (carrier convention for non-status states: value namespace
  `state=decision:go` vs second attribute `stateKind=` vs per-extractor
  interpretation). Stated our lean: registry-operative + optional in-map
  informational mirror. Await reply; no urgency flagged.

- **2026-07-28, rail 270 (832 → AEF, code-verified answers — post-GO, logged
  for the slice record):**
  - **IW-1 preservation facts:** process-level `aef:workflowMeta` does NOT
    have the T-257 guarantee — import reads a fixed 8-key allowlist (their
    src:9263) and export re-synthesizes from known keys only (src:9111); an
    unratified `conformance=` attr is **silently dropped on the first editor
    save**. Node-level `aef:meta` is asymmetric: import ingests all attrs
    verbatim (src:9341), export re-emits from a 17-key allowlist (src:8979) —
    `state=` IS allowlisted (existing carriers round-trip), but a new
    `stateKind=` would drop today. **Net: registry-operative (our chosen
    default, shipped in T-2654) is safe with zero 832 work; in-map declaration
    is unsafe until ratified.** 832 captured the ratification as their T-277
    (inception, parked, operator-owned) — promote on our signal only.
  - **IW-4 taste (schema owner, advisory):** second attribute `stateKind=`
    over value-namespacing — keeps `state=` values plain (existing mixed-kind
    carriers already in the wild), absent-defaults-to-task-status is backward
    compatible with zero corpus edits, extractors dispatch on an attribute
    not value parsing, and it composes orthogonally with `conformance=`.
    Same T-277 ratification needed; per-map-extractor interpretation
    (our shipped interim) covers until then.
  - **Slice-5 consequence:** slice 5 = ping this thread with the direction;
    832 takes T-277 to their operator; only then does any in-map key land.
    Both deferred IWs are now effectively answered in line with the working
    defaults the GO was predicated on — no design change needed.

## Recommendation

**GO** — registry-driven generalization with a three-primitive comparison
library. Full rationale, slice list, and evidence in the task file
(`.tasks/active/T-2652`, `## Recommendation`). In brief:

- Both GO criteria met: all four maps have code-verified enforced sources;
  one shape (framework-side registry → checker with transition-table /
  vocabulary-set / gate-referent primitives) covers everything with zero
  unilateral schema change.
- The 832-facing IWs (in-map mirror, `stateKind`) refine slice 5 only —
  registry-operative + per-extractor state interpretation are the defaults
  either way.
- Slices: (1) registry + primitive-library refactor, (2) inception-flow +
  audit-cron vocabulary rails, (3) dispatch-loop rail, (4) session-lifecycle
  annotation pair-round then rail, (5) 832-dependent schema hardening.
