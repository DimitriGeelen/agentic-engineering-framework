# T-2620: Live-state overlay seam — research artifact (C-001)

Inception exploration record. Created 2026-07-25. Parent decision: T-2619 GO (mirror-first + selective spec-conformance) — see `docs/reports/T-2619-designer-authority-model.md` for the authority-model dialogue this inception executes.

## Question

Minimal seam to project live framework state onto served designer maps, keyed by node uid — serving the TROUBLESHOOT goal at **process level**.

## Settled by operator dialogue (2026-07-25, rounds 1-3)

1. **Content model (IW-1, answered):** headline = process-level aggregates (WIP concentration per stage, gate-friction hotspots). Drill-down descends to **generalized sub-workflows** (subProcess expansion / T-2613 cross-map jumps) — never to individual task pages. Individual task data is the **observation layer**: feeds aggregates, fires **triggers to be actioned** on threshold breach.
2. **Sequencing (IW-2, answered):** ask 832 first. Annotation-seam proposal posted at rail offset 196 — two candidate shapes: (A) postMessage protocol (`{type:'aef:annotate', nodes:[{uid,badge,text,severity}]}` + `aef:ready`), (B) `window.AefDesigner` API. Fallback held: same-origin wrapper iframe DOM-reach (feasible per T-2619 IW-3 spike: zero in-bundle hooks, but same-origin serving guarantees access). Awaiting 832 shape-level ack/counter.

## Open (IW-3, IW-4 + trigger design)

- IW-3: live iframe DOM-reach test against served 0.4.0 (may be superseded by 832 hook acceptance).
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

## Dialogue Log

- **2026-07-25 — Operator:** "how do we start a drafting session… how can I trigger starting a drafting session together with agent?" → agent: chat phrase today ("let's draft <topic>"), `fw designer draft new` + gallery button once T-2623 builds; ritual = agent seeds skeleton, operator edits visually, agent normalizes between versions.
- **2026-07-25 — Operator:** "ok lets go" → session opened on candidate 1 (trigger-handling workflow). v1 skeleton seeded, saved via /api/save, deep link handed over.
