# T-2565 — arc-014 D5: `aef-audit-cron` compile log

**Task:** T-2565 (build, arc-014 `designer-corpus`, corpus diagram 5 of 5 — corpus COMPLETE)
**Date:** 2026-07-19
**Diagram:** `.context/designer/projects/aef-audit-cron/v1.bpmn` (saved via live `POST /api/save` → `{"ok":true,"v":1}`; well-formedness pre-checked before save — D4/T-2564 lesson applied author-side)
**Process documented:** daily audit cron — telemetry pick #5 (748 runs). Sources of truth: `fw audit` exit codes 0/1/2, `.context/audits/` store, `--emit-tasks` (T-100146 focus-theft fix), cron registry chain (T-1942).

## Shape

2 lanes. Agent·Initiative: **typed timer START event** (`kind=timer binding=cron-registry:audit-daily` — schedule source of truth is the registry, noted in aef:meta) → sweep → record findings → "sweep result?" gateway → clean end, or **typed error event** (`kind=error binding=audit:exit-1-or-2`) → emit-tasks. Human·Sovereignty: triage userTask (promote/dismiss/re-prioritise — audit only proposes) → end.

## Verbatim compile output (exit 0)

```
WARN: node 'agt_0_cron' carries a typed-event annotation (aef:eventDef kind=timer) (binding=cron-registry:audit-daily) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'agt_err_findings' carries a typed-event annotation (aef:eventDef kind=error) (binding=audit:exit-1-or-2) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'agt_gw_result' is a exclusiveGateway ('sweep result?') with branches [pass — exit 0 → agt_5_clean; warn/fail — exit 1/2 → agt_err_findings] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

(followed by 4 skeletons: ac_sweep, ac_record, ac_emit `owner: agent`; ac_triage `owner: human`)

## Findings

1. **PASS — third typed-event carrier shape.** D3/D4 validated intermediate catch events and (in Spike-2) boundary events; D5's timer rides a **startEvent** — the detector fires there too. All three carrier shapes now corpus-validated.
2. **PASS — WARN classes.** 2 typed-event WARNs (timer + error) + 1 gateway WARN with branch labels. Nothing silently dropped that a WARN class exists for.
3. **PASS — owner derivation + flow-order horizon.** ac_triage → human; sweep `now` → record `next` → downstream `later`.
4. **No new gap class.** First corpus diagram since D2 with zero new findings — and the D4 lesson (pre-save well-formedness check) was applied author-side, which is the antifragile loop working: the gap became discipline before T-2564 lands as tooling.

## Final corpus scorecard (D1–D5, arc-014)

| Diagram | Process (telemetry rank) | New gap classes | Repeat validations |
|---------|--------------------------|-----------------|--------------------|
| D1 task-lifecycle | 1599+230 events | T-2556 (kind marker), T-2557 (gateway) | — |
| D2 inception-flow | 408/295 | none | T-2557 (1) |
| D3 session-lifecycle | 1387 handovers | T-2562 (self-loop related_tasks) | T-2557 (2), T-2551 timer |
| D4 dispatch-loop | 992/1240 | T-2564 (save accepts malformed XML) | T-2557 (1), T-2551 message |
| D5 audit-cron | 748 runs | none | T-2557 (1), T-2551 timer-on-start + error |

Spike-2 (T-2559, same arc): 832's real fixtures byte-exact, detector parity 3/3 + 2/2, T-2560 (boundary-attachment WARN completeness) filed.

**Accumulator state:** 4 open gap tasks (T-2556 blocked on 832 ratification, T-2560, T-2562, T-2564 — all captured/later with real ACs), 0 gaps fixed mid-flight (grill answer 3 honored; T-2557 was fixed under its own task before D2, by design).
