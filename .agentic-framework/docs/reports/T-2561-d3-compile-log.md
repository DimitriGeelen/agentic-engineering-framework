# T-2561 — arc-014 D3: `aef-session-lifecycle` compile log

**Task:** T-2561 (build, arc-014 `designer-corpus`, corpus diagram 3 of 5)
**Date:** 2026-07-19
**Diagram:** `.context/designer/projects/aef-session-lifecycle/v1.bpmn` (saved via live `POST /api/save` → `{"ok":true,"v":1}`)
**Process documented:** AEF session lifecycle — telemetry pick #3 (handover ran 1387×). Sources of truth: CLAUDE.md §Session Start Protocol, §Context Budget Management (P-009 ladder), §Session End Protocol, §Auto-Restart (T-179), T-1277 push-verify.

## Shape

2 lanes (Human·Sovereignty: launch start-event + review-queue userTask; Agent·Initiative: 5 serviceTasks, 2 gateways, 1 timer event, 2 end events). Two decision points: budget-critical? (with the commit-cadence loop edge back to work) and restart-requested? (T-179 signal file). The one honest `kind=timer` is the claude-fw wrapper's 3-second cancel window (`binding=PT3S`).

## Verbatim compile output (exit 0)

```
WARN: node 'agt_tmr_restart' carries a typed-event annotation (aef:eventDef kind=timer) (binding=PT3S) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'agt_gw_budget' is a exclusiveGateway ('budget critical?') with branches [no — below critical, keep committing → agt_2_work; yes — ≥285K, wrap-up only → agt_3_capture] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
WARN: node 'agt_gw_restart' is a exclusiveGateway ('restart requested?') with branches [yes — signal file present → agt_tmr_restart; no — clean end → hum_8_review] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

(followed by 6 skeletons: sl_init, sl_work, sl_capture, sl_handover, sl_verify — all `owner: agent` — and sl_review `owner: human` from the userTask in the sovereignty lane)

## Findings

1. **PASS — every WARN class accounted for.** 1 typed-event WARN (the timer, T-2551 class) and 2 gateway WARNs with full branch labels (T-2557 class, third live validation since the Pass-4 fix). Nothing silently dropped that a WARN class exists for.
2. **PASS — owner derivation.** Sovereignty-lane userTask → `owner: human`; all initiative-lane serviceTasks → `owner: agent`.
3. **PASS — flow-order horizon.** sl_init `now`, sl_work `next`, downstream wrap-up chain `later` — matches diagram order through the gateway.
4. **NEW MINOR GAP → T-2562.** The commit-cadence self-loop (sl_work → gw_budget → back to sl_work) makes the Pass-2 flow-walk record **sl_work as its own related_task** (`related_tasks: [sl_init, sl_work]`). D1's loop had a distinct back-edge node (tl_heal → tl_work) so this never surfaced. Not silent loss — but a promoted task pointing at itself is meaningless. Filed as T-2562 (captured/later, arc-014): skip self-references in the nearest-task-predecessor accumulation. Logged, not fixed mid-flight (grill answer 3).
5. **Note (known class, no new task):** `triggeredBy`/`terminalKind` meta still dropped silently — same D1 minor, tracked in the T-2555 log.

## Corpus scorecard after D3

| Diagram | New gap classes | Repeat validations |
|---------|-----------------|--------------------|
| D1 task-lifecycle | T-2556 (kind marker), T-2557 (gateway) | — |
| D2 inception-flow | none | T-2557 fix (1 WARN) |
| D3 session-lifecycle | T-2562 (self-loop related_tasks) | T-2557 (2 WARNs), T-2551 timer WARN |
