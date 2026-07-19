# T-2566 — arc-014: compile of 832's pair-draft #1 (`session-handover.bpmn`)

**Task:** T-2566 (test, arc-014 `designer-corpus`)
**Date:** 2026-07-19
**Peer input:** 832 rail offset 92 (their T-214), 11373 B, sha256 `d971a2fc…f5855` — verified byte-exact, pinned at `tests/fixtures/aef-bpmn/session-handover.bpmn`.

832 authored this as (a) a corpus diagram for the session/handover lifecycle and (b) a **deliberate live T-2557 probe** — one exclusiveGateway (`frw_budget`, two named branches with conditionExpressions) plus one back-edge. It is also the first diagram through our compiler with a **third lane authority value**: `Framework · Authority`, `authority="authority"`.

## Verbatim WARN output (exit 0)

```
WARN: node 'frw_budget' is a exclusiveGateway ('Budget critical? (budget-gate ≥150K)') with branches [budget ok → next unit → agt_work; critical → wrap up → agt_capture] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

9 skeletons follow: n_resume, n_focus, n_work, n_commit, n_gate, n_capture, n_handover, n_persist (`owner: agent`) and n_pickup (`owner: human`).

## Results against 832's probe questions

1. **Does frw_budget survive, with labels?** YES — the T-2557 Pass-4 WARN fires with the gateway id, its name, and both branch labels + targets verbatim. Their probe confirms the fix against a peer-authored diagram (fourth independent validation).
2. **Skeleton count/owners:** 9 skeletons; sovereignty userTask n_pickup → human; back-edge through the gateway resolves to the distinct `n_gate` node (`n_work related_tasks: [n_focus, n_gate]`) — no self-reference (T-2562 confirmed self-loop-specific again).
3. **NEW FINDING → T-2567 (silent authority-lane folding).** The three Framework-lane nodes (n_resume/frw_resume, n_gate/frw_ac, n_persist/frw_persist) all derived `owner: agent` **with no WARN**. `AUTHORITY_OWNER` maps only sovereignty→human / initiative→agent; `authority="authority"` falls through to the fallback, and the AEF task model has no "framework" owner — so the folding is semantically lossy and currently silent. Filed as T-2567: WARN naming the lane, the fallback applied, and affected nodes. Sibling of the T-2537 name-only-lane WARN class. Pinned as current behavior in `test_832_handover_authority_lane_current_behavior`.
4. **Tolerated-unknown tags:** `aef:endpoint`, `aef:anchors`, `aef:decisionInput`, `conditionExpression` all pass through the forward-compat tolerance (not consumed, no crash). This is the known T-2552-RCA tolerance class, not a new gap.
5. **Content nit for pair-review (not a compiler issue):** the gateway name says "budget-gate ≥150K"; AEF's actual critical threshold is **285K of a 300K window** (225K warn / 255K urgent / 285K critical, `FW_CONTEXT_WINDOW`). Worth a v2 label correction on 832's side or in the operator's designer pass.

## Regression pins

3 tests appended (suite 43/43 green): sha byte-guard, gateway-probe labels, authority-lane current-behavior pin (moves when T-2567 lands).
