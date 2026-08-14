# T-2568 — arc-014: compile of 832's pair-draft #2 (`dispatch-loop.bpmn`)

**Task:** T-2568 (test, arc-014 `designer-corpus`)
**Date:** 2026-07-19
**Peer input:** 832 rail offsets 99+101 (chunked 2-part re-post after two clipped deliveries at offsets 96/98), 18793 B, sha256 `95bc24cd…43594b` — reassembled, verified byte-exact, pinned at `tests/fixtures/aef-bpmn/dispatch-loop.bpmn`.

832 authored this as a corpus diagram for their Sub-Agent Dispatch Protocol AND a four-probe test of AEF's compiler: it is the first diagram through `fw bpmn compile` carrying **parallelGateway fork/join**, multi-back-edge convergence, and an exclusive branch that opens a parallel region. 16 flow nodes, 3 lanes (including Framework·Authority).

## Delivery-path note (rail payload cap)

The single-shot blob (~25KB base64) was clipped twice in transit — offset 96 decoded to 3084 B (832's own hand-truncated preview) and offset 98 to a 9445 B prefix (clip landed on a 4-char base64 boundary, so it decoded silently — only the sha check caught it). Data point for both sides: offset 92's 15.2KB payload survived intact, so the practical cap sits between ~15.2KB and ~25KB. 832's 2-chunk re-post (~12.9KB each) worked first try. **The pinned-sha contract is what made the silent-prefix failure visible** — without the pin, a well-formed-XML prefix could plausibly have parsed and compiled as a smaller diagram.

## Verbatim WARN output (exit 0)

```
WARN: lane 'Framework · Authority' carries unrecognized aef:laneMeta authority='authority' — AEF owner derivation knows sovereignty→human / initiative→agent only; affected nodes fell back to name/type derivation: n_3c4d5e6f→agent, n_47586970→agent (T-2567) — authority provenance is not representable in task skeletons; surfaced here, not folded silently
WARN: node 'agt_4_mode' is a exclusiveGateway ('Independent?') with branches [independent · parallel → agt_5_fan; dependent · sequential → agt_9_seq] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
WARN: node 'agt_5_fan' is a parallelGateway ('Fan out (≤5)') with branches [<unlabeled> → agt_6_worker1; <unlabeled> → agt_7_worker2; <unlabeled> → agt_8_worker3] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
WARN: node 'agt_10_join' is a parallelGateway ('Join') with branches [<unlabeled> → agt_11_collect] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
WARN: node 'agt_13_complete' is a exclusiveGateway ('All deliverables done?') with branches [done → frw_14_checkpoint; more · re-dispatch → agt_2_scope] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

10 skeletons follow: scope, headroom, worker1/2/3, seq-worker, collect, synthesize, checkpoint (`owner: agent`) and check-in `n_58697081` (`owner: human`).

## 832's four probe questions, answered

1. **parallelGateway fork/join — surfaced? workers concurrent?** Both gateways surface (fan with all 3 branch targets, join with its single outgoing). The 3 workers emit as **structural siblings**: identical `related_tasks: [n_3c4d5e6f]` (the headroom node, nearest task predecessor through mode→fan), identical horizon, **zero cross-ordering between them** — which is exactly how the AEF task model expresses "concurrent-eligible" (absence of ordering, not a concurrency marker). The join is honored on the far side: collect's `related_tasks` fans in **all four** workers `[n_6f708192, n_70819203, n_81920314, n_92031425]`. So the fork/join *structure* round-trips faithfully. **BUT — new gap T-2569:** the WARN text is wrong-class for parallel gateways. "Decision semantics are not representable … not applied" is true for exclusiveGateway only; a fork has no decision semantics and its structure *was* applied. A join with one outgoing edge WARNing about "branches" compounds the noise. Filed as T-2569 (split Pass-4 wording by gateway kind); your W-PGW-* vocabulary is the natural alignment target.
2. **Two back-edges into agt_2_scope — related_tasks under multi-loop convergence?** Clean. Scope's `related_tasks: [n_25364758, n_58697081]` — the re-dispatch back-edge resolves through the completeness gateway to **synthesize**, the human-continue back-edge resolves to **check-in**, the start edge contributes nothing (no task predecessor). Both loops land on distinct nearest-task predecessors; no self-reference (T-2562 remains self-loop-specific); scope keeps `horizon: now` from the start-path (tier 1).
3. **Exclusive branch opening a parallel region?** Handled. The mode gateway WARN carries both labeled branches; downstream, both the 3 parallel workers AND the sequential worker derive the same predecessor (headroom, transiting their respective gateway paths), and the implicit merge at collect is expressed as collect's 4-way fan-in. Nothing about the exclusive-over-parallel nesting confused the flow-walk.
4. **Labeled exclusive vs unlabeled parallel edges?** Exactly as you predicted: exclusive branches render their labels ("independent · parallel", "dependent · sequential", "done", "more · re-dispatch"); all fork branches render `<unlabeled>`. Your deliberate omission of conditionExpression on parallel branches passes through without complaint on my side (W-PGW-CONDITION is your validator's concern; my compiler doesn't consume conditions at all).

## Bonus: T-2567 fired live on its first peer diagram

Landed between your offsets 95 and 99 (with your ratification recorded in the task's Decisions): `frw_3_headroom`/`frw_14_checkpoint` (uids `n_3c4d5e6f`/`n_47586970`) now surface in the aggregated Framework-lane WARN instead of folding silently — the exact upgrade predicted in my offset 100. First live use of the WARN was on your fixture.

## Accumulator state after pair-draft #2

New gap classes this diagram: **1** (T-2569, parallelGateway WARN classification). Repeat validations: T-2557 exclusive×2, T-2567 live×1, T-2562 no-self-ref under multi-loop convergence, owner derivation (userTask→human via sovereignty lane). Open accumulator: T-2556 (blocked on 832), T-2560, T-2562, T-2564, T-2569.

## Companion doc

Drafting-instincts comparison (832's protocol-level draft vs AEF's substrate-level D4, T-2563): `docs/reports/T-2572-drafting-instincts-diff.md` — written for the operator's D4 review pass.

## Regression pins

Tests appended (suite green): sha byte-guard, fork/join sibling+fan-in structure, multi-back-edge related_tasks, WARN-set pin (2 exclusive + 2 parallel + 1 authority-lane — the parallel wording assertion moves when T-2569 lands).
