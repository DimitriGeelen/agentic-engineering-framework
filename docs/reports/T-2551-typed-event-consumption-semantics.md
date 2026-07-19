# T-2551 — AEF consumption semantics for 832 typed BPMN events

**Inception.** Should the AEF compile/promote path *consume* 832's typed BPMN event
annotations (error/timer/message), and if so, what does each kind map to in an AEF task?

Status: **NO-GO** (on building consumption) with a revisit condition. Spike-1 **complete** —
AEF has no consumer for a per-task trigger annotation (verified). The decision is independent
of 832's inbound fixture (that gates only the already-shipped WARN's byte-exactness).

---

## Context

832 landed **T-204 Slice 1 — typed BPMN events** (rail offset 79, 2026-07-19): error/timer/message
encoded as `<aef:eventDef kind= binding=>` on a neutral `intermediateCatchEvent` (no native
`bpmn:*EventDefinition`). Binding scalars: `errorStatus` / `timerSpec` / `busTopic`, carried in
their `KNOWN_AEF_KEYS` (no loud-drop on their side). Producer side done, encoding byte-stable.
They offered a byte-exact fixture for cross-validation (T-2535/T-2536 pattern) and asked whether
the AEF compile/promote path wants to consume the annotations.

## Current AEF compile behavior (grounded, `tools/bpmn_to_tasks.py`)

- **Compiles clean, no crash.** `intermediateCatchEvent` is not in `TASK_TAGS`
  (`{userTask, serviceTask, scriptTask}`, line 51); the parse matches by namespace-agnostic local
  name; `_nearest_task_preds` (line 279) explicitly *transits* non-task nodes. So a typed-event
  diagram parses fine and the event contributes to `related_tasks` edges (T-2532).
- **`<aef:eventDef>` is silently dropped** — no skeleton emitted, no trigger annotation on the
  downstream task. The `kind`/`binding` semantics are lost on compile. This silent-drop is a
  reliability gap on the AEF side (mirror of the loud-drop 832 avoided). Surfacing it (compile
  WARN) is committed as separate work (rail offset 80) and does **not** depend on this go/no-go.

## Dialogue Log

- **832 → AEF (offset 79):** seam closed both sides (their T-208 done). Announced T-204 Slice 1
  typed events; encoding stable; offered typed-event fixture; asked if AEF's promote/compile path
  wants to consume typed-event trigger annotations.
- **AEF → 832 (offset 80):** grounded current-state finding (clean compile + silent-drop). Said
  YES to the fixture (cheap forward-compat cross-validation) and committed to surfacing the
  silent-drop as a compile WARN. Explicitly split scope: consumption *semantics* is a separate
  scoping decision (this inception, T-2551), not a same-session build; won't ratify any mapping
  until scoped.

## Spike 1 (load-bearing) — does AEF have a live consumer for a per-task trigger annotation?

**Method:** trace what reads task frontmatter in the execution/orchestration layer (resolver,
healing, cron, bus/inbox). **IW-1 is load-bearing: no consumer → NO-GO regardless of encoding.**

**Findings:**

| Event kind | Candidate AEF consumer | Live consumer today? | Note |
|-----------|------------------------|----------------------|------|
| **timer** | `horizon` (resolver eligibility line 1176 + `_rank`) | **YES** | But T-2532 **already** derives `horizon` from sequenceFlow order → overlap/tension. A `timerSpec` binding could *refine* it, not create a net-new consumer. |
| **error** | healing (`status: issues`) | **NO** (compile-time) | Healing triggers on *live* status transitions, not a compile-time field. Setting `status: issues` at birth is semantically wrong (a trigger ≠ current state). Best-case: a `related_tasks`-style "on error → T-X" edge, but nothing *reads* it as a trigger. |
| **message** | bus / inbox / pause dispatch | **NO** (compile-time) | Dispatch is keyed on *runtime* events (`inbox.queued`), not a per-task frontmatter annotation. No consumer reads a compile-time "message trigger" field. |

`lib/resolver.py:611 load_task_frontmatter` reads a **fixed** key set (`horizon`, `status`,
`bvp_scores`, …) — there is no arbitrary trigger/event field consumption. The scheduler
(`_pick`/`_rank`) gates and ranks on `(status, horizon, bvp quadrant)` only.

**Preliminary conclusion (confidence 2, not ratified):** only **timer** maps onto an existing live
consumer, and that path largely overlaps T-2532's existing `horizon` derivation. **error** and
**message** would be write-only frontmatter — nothing in the current AEF model reads them as
triggers — which is the NO-GO criterion (consumption = noise, D2/D3). The already-committed
visible-drop WARN preserves the "no silent loss" guarantee without inventing a consumer.

**Confirmed (Spike-1 complete):** the resolver dispatch envelope reads exactly six frontmatter
fields — `id/name/workflow_type/owner/horizon/status` (`lib/resolver.py:1056-1061`). A grep of
resolver/outcome/pause/pending/spawn for any trigger/event/`on_error`/`eventDef` consumer returns
empty. So IW-1 is answered (confidence 3): **no consumer exists** for a compile-time trigger
annotation. Recommendation upgraded DEFER → **NO-GO** — the consumption decision does not depend on
the fixture (which gates only the WARN's byte-exactness, already shipped in T-2552).

## Candidate directions (to be sharpened in Spike 3)

- **C-A — WARN-only (no consumption):** surface the silent-drop as a compile WARN; do not consume.
  Preserves reliability; zero write-only noise. *Currently the strongest per Spike-1.*
- **C-B — timer→horizon refinement only:** consume `timerSpec` to refine `horizon`, leave
  error/message as WARN. Bounded, but overlaps T-2532 and risks D4 (locking to 832's timer vocab).
- **C-C — full consumption (all three kinds → frontmatter annotations):** rejected-trending — two
  of three kinds have no consumer; adds noise.

## Open dependencies (why DEFER is honest, not a hedge)

1. **832's typed-event fixture** — external; needed for byte-exact encoding cross-validation before
   any consumption is built.
2. **Human go/no-go** — whether to pursue consumption at all, given Spike-1 trends NO-GO. This is a
   sovereignty call (do we want the AEF task model to carry producer-trigger vocabulary?).

Both are genuine gaps, not confidence hedges (see `feedback_defer_for_evidence_not_confidence`).
