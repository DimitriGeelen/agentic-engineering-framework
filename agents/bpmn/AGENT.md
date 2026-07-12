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

Namespace-agnostic: matches BPMN/aef elements by **local name**, so it is forward-compatible
with 832's real `aef:` namespace URI when the vendored corpus lands.

## Roadmap

- **Slice 1 (T-2531, done):** node → skeleton (uid, lane→owner, O-1).
- **Slice 2 (T-2532, done):** sequenceFlow → horizon + related_tasks.
- **Slice 3a (T-2533, this):** `fw bpmn compile` CLI verb.
- **Slice 3 (blocked on 832):** gateway *semantics* — collapsed-subProcess (`aef:scopeOf`, 832 T-081)
  → `workflow_type: inception` + `owner: human` on the go/no-go decision node (rulings #1/#2, O-3).
  Needs 832's `aef:scopeOf` serialization answer (rail offset 30, Q1-Q3).
- **Later:** write-out mode (emit real `.tasks/` files, not stdout); real-corpus validation once
  832 packages the 24-map fixture drop.
