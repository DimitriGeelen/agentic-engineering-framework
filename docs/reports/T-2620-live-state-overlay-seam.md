# T-2620: Live-state overlay seam — research artifact (C-001)

Inception exploration record. Created 2026-07-25. Parent decision: T-2619 GO (mirror-first + selective spec-conformance) — see `docs/reports/T-2619-designer-authority-model.md` for the authority-model dialogue this inception executes.

## Question

Minimal seam to project live framework state onto served designer maps, keyed by node uid — serving the TROUBLESHOOT goal at **process level**.

## Settled by operator dialogue (2026-07-25, rounds 1-3)

1. **Content model (IW-1, answered):** headline = process-level aggregates (WIP concentration per stage, gate-friction hotspots). Drill-down descends to **generalized sub-workflows** (subProcess expansion / T-2613 cross-map jumps) — never to individual task pages. Individual task data is the **observation layer**: feeds aggregates, fires **triggers to be actioned** on threshold breach.
2. **Sequencing (IW-2, answered):** ask 832 first. Annotation-seam proposal posted at rail offset 196 — two candidate shapes: (A) postMessage protocol (`{type:'aef:annotate', nodes:[{uid,badge,text,severity}]}` + `aef:ready`), (B) `window.AefDesigner` API. Fallback held: same-origin wrapper iframe DOM-reach (feasible per T-2619 IW-3 spike: zero in-bundle hooks, but same-origin serving guarantees access). Awaiting 832 shape-level ack/counter.

## 832's seam answer (rail 197, 2026-07-26 — advisory, their operator ratification pending)

832's agent lean: **(A) postMessage** — origin-independent, no global namespace in the bundle. Load-bearing contract detail they surfaced: their `renderAll()` rebuilds the SVG DOM on every render, so annotations are wiped by any edit/re-render. Durable contract: **bundle re-emits `aef:ready` after EVERY render; we re-send `aef:annotate` each time.** Designer-side constraints they'd hold: read-only presentation (badge/class on `g[data-id=uid]` only), never serialized, dropped on document switch, unknown uids ignored silently (live state may outrun the loaded map version). Capability advertised via MANIFEST capabilities block — our ask was the promotion trigger for their parked T-246. Their side captured as **T-250** (inception, operator-gated, parked behind T-249 + operator reviews). Iframe DOM-reach fallback mutually parked as the coupling versioned releases exist to prevent. Acked at offset 201. **IW-3 effectively resolved at shape level** — v0 plans against the postMessage + re-ready/re-annotate contract; build waits for their ratification.

## Open (IW-4 + trigger design)

- IW-4: feed shape — single Watchtower aggregation endpoint vs per-source fetches. Lean: single endpoint.
- Trigger landing surface: observations inbox (`fw note obs`, agent lean) vs /approvals vs overlay-page panel — operator undecided; also drafted as an explicit decision-point node in the pair-draft below.

## Pair-draft: draft-trigger-handling v1 (2026-07-25)

First live drafting session under the T-2623-endorsed ritual — the trigger-handling workflow drafted *in the designer itself*.

- **Project:** `.context/designer/projects/draft-trigger-handling/` v1 — 19 nodes, 20 flows, 3 lanes.
- **Proposed third lane** `Framework · Authority` (mirrors the CLAUDE.md authority model; draft question: is observation machinery a lane actor or plumbing?).
- **Shape:** observation cycle → snapshot (task data = observation only) → threshold eval → breach? → quiet end / typed message throw → agent catch → diagnose (drill-down rule encoded as note) → outcome gateway → propose-task (captured, never steals focus; handoff → aef-task-lifecycle) / propose-redesign (self-referential draft-mode loop) → operator triage → act / park / dismiss-with-rationale → **tuning feedback edge** dismiss → threshold eval (antifragility: false positives sharpen the observer).
- **Hygiene:** typed throw/catch paired (no emitterless finding); corpus lint stays at the 2-finding steady baseline; live-verified in served designer (19/19 nodes + 20/20 flows render, 3 lanes, console clean except known favicon 404).
- **Open decision points marked as node notes:** cadence (cron vs page-load), threshold values + tuning source, trigger landing surface, third-lane question.
- Operator holds the pen next: edit in UI, save vN; agent re-derives, critiques, normalizes.

## Pair-draft round 2: v2 (operator) → v3 (agent normalize), 2026-07-26

- **v2 (operator, "layout corrected"):** pure layout pass — end-states aligned into a right-hand column (x≈1885.8), Human lane drag-resized to fractional height 323.916…, hand-tuned edge anchors/routing hints. **All 19 nodes, 20 flows, and every uid preserved; handoff auto-resolved name→workflowRef uuid (aef-task-lifecycle).** The uid identity contract held under real operator editing — first live proof.
- **Defect found (832-side):** editor save **drops `<aef:eventDef>` from startEvent and intermediateThrowEvent carriers but keeps it on intermediateCatchEvent** — silently strips typed-event semantics, manufacturing the emitterless-typed-catch lint class (T-2551). Reported to 832 at rail offset 201 with repro + fixture offer.
- **Defect found (our side, spun out as T-2625, fixed + completed):** `corpus_spec.py` derive crashed on the fractional lane height (`int()` coercion; editor saves full-precision floats). Fixed with integral-stays-int/fractional-verbatim parsing; regression test pins both directions; the draft map itself now exercises the path corpus-wide.
- **v3 (agent):** v2 verbatim + both eventDefs restored with normalize-notes. **Verified:** corpus lint at 2-finding baseline, derive round-trips the fractional height verbatim, live-loads in designer 0.5.0 (39 g[data-id] = 19 nodes + 20 flows exact, console clean except favicon 404).
- **Charter note:** first pair-draft round surfaced two real defects (one each side) — exactly the accumulator value arc-014 chartered the ritual for.

## Dialogue Log

- **2026-07-25 — Operator:** "how do we start a drafting session… how can I trigger starting a drafting session together with agent?" → agent: chat phrase today ("let's draft <topic>"), `fw designer draft new` + gallery button once T-2623 builds; ritual = agent seeds skeleton, operator edits visually, agent normalizes between versions.
- **2026-07-25 — Operator:** "ok lets go" → session opened on candidate 1 (trigger-handling workflow). v1 skeleton seeded, saved via /api/save, deep link handed over.
