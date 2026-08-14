# T-2563 — arc-014 D4: `aef-dispatch-loop` compile log

**Task:** T-2563 (build, arc-014 `designer-corpus`, corpus diagram 4 of 5)
**Date:** 2026-07-19
**Diagram:** `.context/designer/projects/aef-dispatch-loop/v2.bpmn` (v1 malformed → v2 fixed; both saved via live `POST /api/save`)
**Process documented:** v1 dispatch-orchestration loop — telemetry pick #4 (dispatch 992/1240 events). Sources of truth: `fw resolver dispatch` (envelope + dispatches.jsonl), `fw termlink dispatch` (T-577 watchdog), fw bus result ledger, paused-dispatch chain (pause_requested → `fw pause resolve` → retry_of_dispatch_id), `fw outcome evaluate/backprop`.

## Shape

2 lanes. Agent·Initiative: resolver → spawn worker → **message catch event** (worker result on bus, the honest `kind=message`) → "worker paused?" gateway → outcome/backprop → end; retry serviceTask loops back to spawn. Human·Sovereignty: one userTask — `fw pause resolve` (the worker asked, only the operator answers).

## v1 → v2: two findings from one malformed save

**Finding A (authoring):** v1 had a raw `<dispatch_id>` inside an `aef:meta note` attribute — not well-formed XML. `fw bpmn compile` fails with `ParseError: not well-formed (invalid token): line 62, column 75` (exit 1). Correct behavior on the compile side: fail fast, actionable position info.

**Finding B (NEW GAP → T-2564):** the gallery API **accepted the malformed payload** — `POST /api/save` returned `{"ok":true,"v":1}` and persisted the broken XML to the store. No well-formedness check at save time; the failure only surfaces later, at compile, or worse: in the designer UI on next load. Filed as T-2564 (captured/later, arc-014): save-side parse check → HTTP 400 with line/column, nothing written. Logged, not fixed mid-flight (grill answer 3).

## Verbatim compile output — v2 (exit 0)

```
WARN: node 'agt_msg_result' carries a typed-event annotation (aef:eventDef kind=message) (binding=bus:task-channel) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'agt_gw_paused' is a exclusiveGateway ('worker paused?') with branches [yes — pause_requested → hum_3_pause; no — completed → agt_5_outcome] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

(followed by 5 skeletons: dl_resolve, dl_spawn, dl_retry, dl_outcome — `owner: agent` — and dl_pause_resolve `owner: human`)

## Findings

1. **PASS — WARN classes.** 1 message typed-event WARN (first `kind=message` in the corpus) + 1 gateway WARN with branch labels. Nothing silently dropped that a WARN class exists for.
2. **PASS — owner derivation.** Sovereignty userTask dl_pause_resolve → human; all initiative serviceTasks → agent.
3. **PASS — distinct-node loop.** The retry back-edge (dl_retry → dl_spawn) yields `dl_spawn related_tasks: [dl_resolve, dl_retry]` — no self-reference (contrast D3's T-2562 self-loop case; this confirms the gap is specific to loops that return to the SAME task).
4. **NEW GAP → T-2564** (save-side XML validation, Finding B above).

## Corpus scorecard after D4

| Diagram | New gap classes | Repeat validations |
|---------|-----------------|--------------------|
| D1 task-lifecycle | T-2556 (kind marker), T-2557 (gateway) | — |
| D2 inception-flow | none | T-2557 (1 WARN) |
| D3 session-lifecycle | T-2562 (self-loop related_tasks) | T-2557 (2), T-2551 timer |
| D4 dispatch-loop | T-2564 (save accepts malformed XML) | T-2557 (1), T-2551 message, distinct-node loop clean |
