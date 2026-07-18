# BPMN Agent — Child-2 Forward Compiler

Compiles a BPMN 2.0 process diagram into AEF task skeletons. This is the **forward bridge**
of the AEF ↔ 832-Workflow-Designer integration (diagram → tasks), the primary value path.

## Invocation

```
fw bpmn compile <file.bpmn>   # emit AEF task-skeleton YAML frontmatter to stdout
fw bpmn help
```

Mechanical script: `agents/bpmn/bpmn.sh` → `tools/bpmn_to_tasks.py`.

## What it maps (ratified contract — see docs/reports/T-2522-bpmn-aef-mapping-contract.md)

| BPMN | AEF | Ruling |
|------|-----|--------|
| task node (`userTask`/`serviceTask`/`scriptTask`) | one task skeleton | — |
| `aef:uid` in `<extensionElements>` | `id` (stable identity) | IW-1 keystone |
| lane | `owner` (`human`/`agent`) — from lane only, node-owner ignored | IW-7 / IW-9 (832 T-189) |
| node-type vs lane conflict | Lane wins + WARN | O-1 |
| `sequenceFlow` order (task-hops from start) | `horizon` (tier1→now, tier2→next, tier≥3→later) | T-2532 |
| nearest task predecessor (gateways/events transited) | `related_tasks: [uid…]` | T-2532 |
| node kind | `workflow_type: build` (default), `tier: 1` (default) | ratified defaults |
| `subProcess` + `<aef:meta workflowType="inception">` | `workflow_type: inception` + `owner: human` | T-2534 (slice 3) — G-3 implied go/no-go |
| `<aef:laneMeta authority="sovereignty">` | `owner: human` (authority-of-record) | T-2534 / IW-7 |
| `<aef:constituents>` on inception subProcess | `# constituents:` AC-seed comment | T-2534 |

Namespace-agnostic: matches BPMN/aef elements by **local name**, so it is forward-compatible
with 832's real `aef:` namespace URI when the vendored corpus lands.

## Roadmap

- **Slice 1 (T-2531, done):** node → skeleton (uid, lane→owner, O-1).
- **Slice 2 (T-2532, done):** sequenceFlow → horizon + related_tasks.
- **Slice 3a (T-2533, done):** `fw bpmn compile` CLI verb.
- **Slice 3 (T-2534, done):** inception *semantics* — a `subProcess` with
  `<aef:meta workflowType="inception">` → `workflow_type: inception` + `owner: human`
  (owner from `<aef:laneMeta authority="sovereignty">`; go/no-go implied at the boundary,
  no child gateway). 832's ratified contract, rail offset 32/34. Positive fixture
  `inception-gonogo-sample.bpmn` (AEF twin of 832's `inception-gonogo.bpmn`), negative
  `plain-composite-sample.bpmn`. Correction from the offset-30 guess: the marker is
  `workflowType`, NOT `scopeOf` (scopeOf is the T-081 composition back-ref).
- **Slice 3 cross-validation (T-2535, done):** byte-exact against 832's canonical
  `inception-gonogo.bpmn` (positive, sha `093858…`) and `resume-status.bpmn` (negative,
  sha `7b15f3e0…`), both delivered inline over the DM rail. This caught the uid-attribute
  bug (T-2536): 832 serializes uid as `<aef:uid value="X"/>`, not text content.
- **O-3 fail-fast (T-2537, done):** O-3 graduated to v1.1 (832 T-195, rail offset 47) as
  MUST + machine-checkable G-3 — an inception's go/no-go boundary MUST be sovereignty-laned.
  A mis-laned inception now raises `MalformedInceptionError` (CLI exit 3, actionable ERROR),
  superseding the pre-graduation force-human+WARN. Fixture: `inception-mislaned-sample.bpmn`.
- **O-3 VETO tightening (T-2540, done):** 832 VETOed (rail offset 49) the T-2537 name-only-"Human"
  accept+WARN ramp. Per mapping-v1 §3 (IW-9, v1.1) `<aef:laneMeta authority>` is the SOLE
  authority-of-record — a lane NAME is not an authority carrier. So **only `authority="sovereignty"`
  satisfies O-3**; name-only-Human, no-lane, laneMeta-without-@authority, and non-sovereignty
  authority ALL raise identically (§7). The gate now keys off `authority` directly, not the
  name-folded `lane_owner`, structurally excluding the name heuristic from the sovereignty check.
  Conformance fix to an already-frozen fence (no sovereign GO needed). `inception-nameonly-lane-sample.bpmn`
  moved warn-set → raises-set. Also locks PL-035 (832 offset 50): an existence rule must fire
  HARDEST on absent input — the inline node-loop check has no early return, so a no-laneSet inception
  raises (regression-locked by `test_no_laneset_inception_raises`).
- **Write-out staging (T-2539, done — from T-2538 GO):** `fw bpmn compile --write` stages
  uid-keyed *proposals* to `.context/bpmn-staged/<diagram>/` (one `<uid>.md` per node +
  `manifest.yaml`). Proposals are `status: proposal`, NOT tasks — no `.tasks/` write, no gate,
  no T-ID allocation (C1). Idempotent upsert by `aef:uid`; stale proposals pruned. This is
  candidate C of the T-2538 governance inception (`docs/reports/T-2538-writeout-mode-governance.md`).
- **Follow-up (promotion slice, gated):** `fw bpmn promote <uid|all>` → real tasks via
  `fw task create`, recording the uid↔T-ID cross-ref. BLOCKED on 832's id-mapping contract
  (IW-2, surfaced rail offset 48). Real-corpus breadth validation descoped (discriminator
  proven both ways against 832's real bytes).
