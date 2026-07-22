# T-2602 — Spec-driven corpus map authoring (inception)

**Question:** Should corpus workflow maps be authored from declarative, git-tracked specs
with a deterministic generator + lint + delete/recreate repeatability proof — replacing
ad-hoc XML surgery?

**Status:** inception, GO recommended (operator-initiated direction)

## Origin

Operator steer (2026-07-22, verbatim intent): *"what i care most about is a repeatable
reliable transferable process, not this particular workflow — fine with deleting it and
then recreating, that would actually prove repeatable, consistent, correct and reliable."*

Evidence base — the T-2600/T-2601 failure pair, same day:

- T-2600 (defective fix): ad-hoc python string-splice into `aef-dispatch-loop` v2 XML
  produced (a) a duplicate handoff glyph next to a bundle-misclassified typed event,
  (b) a **contract violation** — legacy `targetWorkflow` name-ref instead of the ratified
  `workflowRef` uuid form (T-2571 offset-109) — authored the same week the contract was
  ratified, with nothing structural to stop it.
- T-2601 (RCA): the investigation itself was grep-shaped; the rendered surface was never
  looked at until the operator escalated. A generator + lint would have caught both
  defect classes mechanically (ref-form lint; handoff-pair lint).
- Pre-existing corpus gap the same RCA surfaced: `agt_msg_result` typed event has no
  emitter anywhere in the corpus (T-2551/T-2552 seam) — invisible because nothing
  lints the corpus as a *system* of maps.

## Design sketch (exploration target, not commitment)

1. **Spec** — one YAML per map under `corpus/specs/` (name TBD): lanes, nodes (typed:
   task kinds, typed events with `kind=`/`binding=`, handoff pairs), flows, notes,
   layout hints. Human-reviewable diffs; git history = corpus history.
2. **Generator** — `fw corpus generate <spec>` → BPMN XML conforming to contract v0:
   uuid `workflowRef` enforced (resolves via /api/list at generate time; unresolvable →
   explicit ghost-intent marker, never a silent name-ref), `aef:eventDef` vocabulary,
   wiring invariants (throw handoffs are branch terminals; catch handoffs carry targets).
   Saves through `/api/save` like any author (registry sync fires; no store writes).
3. **Lint** — `fw corpus lint`: per-map (all refs resolve, no legacy-form refs, every
   handoff pair bidirectional or explicitly marked one-way with rationale) + cross-map
   (every typed event binding has an emitter or an explicit `seam-pending:` marker).
   Extends the T-2552 compile-WARN leg rather than forking it.
4. **Repeatability proof** — `fw corpus prove <id>`: snapshot served version → delete →
   regenerate from spec → semantic-identical check (canonical-form compare, not byte,
   since server stamps versions/timestamps) → restore is a no-op because regeneration IS
   the restore. Run in CI over the whole corpus.

## Spikes (bounded)

- S1: reverse-derive a spec from served `aef-dispatch-loop` + `aef-task-lifecycle`;
  hand-run generator concept → identical semantic XML? (proves the spec can carry
  everything the maps express — positions, notes, eventDefs)
- S2: canonical-form comparator (what "identical" means with server-stamped fields)
- S3: lint rule inventory vs the defect classes actually observed (T-2600, T-2551 gap,
  T-2584 ghost class) — each shipped rule must cite an observed defect

## Assumptions to validate

- A1: the 832 bundle round-trips generator-produced XML without normalizing it into
  a different shape on first manual save (else spec drifts from reality on first edit)
  → task IW-2
- A2: manual edits in the designer remain possible — flow: edit in designer → export →
  spec update (reverse path) OR spec is authoritative and designer is read/annotate.
  **This is the key design decision and needs operator input** (who wins: spec or canvas?)
  → task IW-1
- A3: semantic-identical comparison is definable (S2) — else "recreate" can't be proven
  → task IW-3

## Go/No-Go criteria

GO if: S1 shows a spec can express the existing corpus faithfully AND A2/IW-1 has an
operator-chosen answer. NO-GO if: the bundle normalizes XML such that round-trip
identity is unachievable (A1/IW-2 fails) — then the process pivots to lint-only (still
valuable, smaller).

## Dialogue Log

- **Operator (2026-07-22):** cares most about repeatable/reliable/transferable process,
  not this workflow; delete-and-recreate would *prove* repeatability; asked for
  reflection. → Agent reflection: T-2600 was artifact-surgery; delete/recreate is the
  infrastructure-as-code acceptance standard; filed this inception rather than building
  on a nod (new mechanism = inception per governance).
- **Interaction with the paused T-2601 fix:** Option A/B/C for the dispatch-loop map is
  superseded if this GOes — the corrected dispatch-loop becomes the first spec-authored
  map (recreate = the fix). If NO-GO/DEFER, T-2601 falls back to Option A by hand.

## Recommendation

**GO** — operator-initiated direction, observed-defect evidence base, bounded spikes,
existing substrate to build on (/api/save, T-2552 lint leg, sha-pin fixture discipline
from the 832 seam). Decision belongs to the operator at /inception/T-2602.

---

## T-2605 follow-up — recreate flow as executed (2026-07-22)

The GO's acceptance test ran end-to-end. `fw corpus prove <map-id>` is the harness
(tools/corpus_spec.py `cmd_prove`); `aef-dispatch-loop` was the first recreate.

**Default leg — identity-preserving recreate (what `prove` does):**
1. Snapshot the served latest (`/api/version`), compute its canonical form.
2. Derive the spec **in-memory** from that snapshot (T-2608 single stored
   representation: the store XML is the only persisted truth; `--spec` accepts a
   transient authoring file, `--from <git-ref>` regenerates from history).
3. Delete every **version** (`/api/delete scope:version` per version) — meta.json
   and its uuid survive.
4. Regenerate via `emit_map` → `/api/save`; the server's
   `meta.setdefault("uuid", …)` no-ops because the uuid is still there.
5. Fetch the served result; PASS iff canonically IDENTICAL and uuid unchanged.

First run: PASS — uuid `e32a518c-01de-4243-aafc-691cc99caf0d` preserved, canonical
IDENTICAL, and `fw corpus lint` dropped aef-dispatch-loop's own `legacy-ref`
finding (regeneration emits the contract-v0 `workflowRef` uuid form). Re-running
`prove` on the recreated map is idempotent (verified post-retrofit).

**The identity-preservation constraint (why version-scope, not map-scope):**
`/api/save` mints the uuid server-side and ignores the XML's workflowMeta uuid. A
map-scope delete destroys meta.json, so recreate mints a FRESH uuid and every
referrer pinned to the old uuid goes ghost — the recreate itself would break
T-2573 immutable identity.

**DR leg (map-scope delete happened anyway) — pinned hermetically in
`tests/web/test_designer_dr_recreate.py`, never run on the live corpus:**
recreate under the same id mints uuid B ≠ A → referrer re-save registers A as a
ghost → `fw bpmn claim A <id>` **refuses** while the map owns B (gotcha: manually
strip the auto-minted `uuid` key from meta.json first) → claim then rebinds A,
removes the ghost, records the claim, and the referrer resolves live again.
