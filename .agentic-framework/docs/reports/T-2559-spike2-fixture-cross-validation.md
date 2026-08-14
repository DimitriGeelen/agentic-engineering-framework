# T-2559 — arc-014 Spike-2: cross-validation against 832's real T-204 fixtures

**Task:** T-2559 (test, arc-014 `designer-corpus`)
**Date:** 2026-07-19
**Peer input:** 832 rail offsets 88/89 (dm topic, fp 6a646ce8), fixtures pinned at 832 master `2bff553`

## What was validated

832 delivered both T-204 round-trip fixtures rail-inline as base64 + SHA256 pins.
This closes the gap that T-2552's WARN leg was validated only against a synthetic
fixture: Spike-2 runs the detector against the PEER's real encoding (L-501), and
`boundary-events.bpmn` is 832's explicit counter-example test of my offset-85 claim
("the detector iterates ALL nodes, so boundaryEvent should fire too").

## 1. Byte-exact verification — PASS

| File | Bytes | SHA256 | Match |
|------|-------|--------|-------|
| `tests/fixtures/aef-bpmn/typed-events.bpmn` | 4556 | `5467071b3a390962…d91d2ca5ff` | ✓ pin |
| `tests/fixtures/aef-bpmn/boundary-events.bpmn` | 5509 | `37eec1b0f10ad02a…da6d106f1a` | ✓ pin |

Decoded from the rail payloads, sha256 computed locally, both identical to 832's
pins. Vendored unmodified under `tests/fixtures/aef-bpmn/` (mirrors 832's own path),
guarded by `test_832_fixtures_byte_exact`.

## 2. typed-events.bpmn — PASS (3/3 WARNs, no silent drop)

Verbatim `bin/fw bpmn compile tests/fixtures/aef-bpmn/typed-events.bpmn` (exit 0):

```
WARN: node 'ev_err' carries a typed-event annotation (aef:eventDef kind=error) (binding=status:issues) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'ev_tmr' carries a typed-event annotation (aef:eventDef kind=timer) (binding=0 9 * * *) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'ev_msg' carries a typed-event annotation (aef:eventDef kind=message) (binding=bus:designer-events) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
```

All three intermediate catch events fire, each with node id, kind, and binding
scalar. Zero task skeletons emitted (the fixture has no TASK_TAGS nodes) — correct.

## 3. boundary-events.bpmn — offset-85 claim HOLDS (2/2 boundary WARNs)

Verbatim `bin/fw bpmn compile tests/fixtures/aef-bpmn/boundary-events.bpmn` (exit 0):

```
WARN: node 'bnd_err' carries a typed-event annotation (aef:eventDef kind=error) (binding=status:issues) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
WARN: node 'bnd_tmr' carries a typed-event annotation (aef:eventDef kind=timer) (binding=0 0 * * *) — AEF does not consume typed events yet (T-2551); surfaced here, not applied
---
id: n_host
name: "do the work"
owner: agent
workflow_type: build
tier: 1
horizon: now
related_tasks: []
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---
```

Both `<bpmn:boundaryEvent>` variants fire the typed-event WARN — the detector does
iterate all nodes, not just `intermediateCatchEvent`. The host serviceTask emits one
agent/build skeleton (`n_host`). 832's counter-example does NOT prove a gap on the
detection axis.

## 4. Honest finding → T-2560 (arc-014 accumulator)

The WARN surfaces **kind + binding only**. The boundary *attachment* semantics drop
without mention:

- `attachedToRef="task_host"` (which activity the event guards)
- `cancelActivity="true|false"` (interrupting vs non-interrupting — semantically load-bearing)
- `<aef:boundaryPos value=…>` (presentational, least important)

This is the sibling class of the T-2557 gateway finding: partially surfaced instead
of fully silent, but a reader of the WARN cannot tell `bnd_err` is an *interrupting*
boundary on `n_host` vs a free-standing intermediate event. Filed as **T-2560**
(captured/later, arc-014): extend the Pass-3 WARN with attachment context when the
carrying node is a boundaryEvent. Additive-only; existing WARN text for non-boundary
nodes unchanged.

Per 832's offset-89 note this is exactly the WARN-first buffer case — flagged to 832
rather than silently diverging.

## 5. Regression pins

`tests/unit/test_bpmn_to_tasks.py` (+3, suite 40/40 green):

- `test_832_fixtures_byte_exact` — sha256 guard on both vendored fixtures
- `test_832_typed_events_fixture_three_warns_no_skeletons`
- `test_832_boundary_events_detector_fires_on_boundary_nodes` — pins the offset-85 claim + records the T-2560 limit

## Verdict relayed to 832

Detection axis: full parity on their real fixtures (3/3 intermediate, 2/2 boundary,
byte-exact). One WARN-completeness gap self-filed (T-2560). No 832-side
reconciliation needed on these two fixtures.
