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
  superseding the pre-graduation force-human+WARN. A name-only "Human" lane (no laneMeta)
  is accepted with a conformance WARN (pre-laneMeta compat). Fixtures:
  `inception-mislaned-sample.bpmn` (raises), `inception-nameonly-lane-sample.bpmn` (warn).
- **Follow-up:** write-out mode (emit real `.tasks/` files, not stdout); real-corpus
  breadth validation descoped (discriminator proven both ways against 832's real bytes).
