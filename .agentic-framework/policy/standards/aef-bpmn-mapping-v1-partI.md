# Part I — Frozen (v1)

## 1. The two attribute classes

Every `aef:` datum is exactly one of two classes. This partition is **normative** — it bounds what a diagram
edit may propose:

- **Semantic (governance-bearing):** compiles into / out of task-YAML fields. The forward compile MUST read
  only this class. Includes the structured elements `aef:artifactsWrites`, `aef:contextReads`,
  `aef:decisionInput`/`aef:decisionOutputs`, `aef:io`/`aef:input`/`aef:output`, `aef:constituents`,
  `aef:link`, the identity key `aef:uid`, and the scalar **governance meta-keys** carried as attributes of
  `aef:meta` (§3).
- **Presentational (diagram cosmetics):** `aef:position`, `aef:anchors`, `aef:endpoint`, `aef:waypoint`,
  `aef:routing`, `aef:routingHint`, `aef:forceStraight`, `aef:loopDetour`, and the `aef:extensionElements`
  wrapper. The reverse compile MAY write these (layout) but MUST treat them as derived, never authoritative.
  A change to a presentational attribute alone MUST be a no-op for the task graph.

## 2. Governance meta-keys carried on `aef:meta`

Scalar governance fields are emitted as **attributes of the single `aef:meta` element** (not standalone
`aef:<key>` elements). The editor's `metaKeys` writer and the Python bridge's `META_KEYS` whitelist govern
this channel; the invariant *editor `metaKeys` ⊆ bridge `META_KEYS`* is enforced by
`tests/test_editor_bridge_meta_parity.py` (T-060).

The **frozen v1 governance meta-keys** — those with a defined task-YAML field mapping and a closed value set —
are the following. A conformant editor MUST emit each on task-like nodes, and the bridge MUST round-trip each:

```conformance-governance-meta-keys
horizon
workflowType
tier
agentType
```

| `aef:meta` key | Task-YAML field | Allowed values | Default when absent |
|---|---|---|---|
| `horizon` | `horizon` | `now` \| `next` \| `later` | `now` |
| `workflowType` | `workflow_type` | build \| test \| refactor \| decommission \| specification \| design \| inception | inferred from BPMN type (service/script→build; user→human-facing) |
| ~~`owner`~~ *(derived — see §3)* | `owner` | `human` \| `agent` | **derived from the node's lane (Axis 1); no node-level override.** `owner` remains in task-YAML output but has no node-level BPMN carrier in v1.1. |
| `tier` | enforcement tier | `0`..`3` | project default |
| `agentType` | agent assignment | `primary` \| `termlink-worker` \| `human` | `primary` |

> Additional keys exist in the editor `metaKeys` set (gateway/sub-process-structural and editor-internal,
> e.g. `gatewayKind`, `scopeOf`, `decisionOwner`); they are covered by the parity test but are **not** part of
> the frozen v1 governance-scalar contract and MAY change without a standard bump.

## 3. Forward mapping (diagram → proposed governed work)

The forward compile produces a **proposed** task/inception graph (never silently authored — IW-1/IW-3;
approval is a separate sovereignty gate).

| BPMN element | AEF concept | Notes |
|---|---|---|
| Process (whole diagram) | Proposed task graph (arc if large) | `aef:arc` on the process when the flow is a program |
| Lane (swimlane) | owner/agent for its tasks | human lane → `owner: human`; agent lane → `owner: agent` |
| userTask | Task, `owner: human` | `workflow_type` via `aef:meta workflowType` |
| serviceTask | Task, `owner: agent`, `workflow_type: build` | agent-executed |
| scriptTask | Task, `owner: agent`, `workflow_type: build\|test` | disambiguate via `workflowType` |
| exclusiveGateway (XOR) | Decision / gate | outgoing edges = branches; edge label = condition |
| parallelGateway (AND) | Fan-out / fan-in | fork = independent tasks; join = barrier |
| subProcess | Arc or composite task | `aef:constituents` = members; collapsed = child arc |
| startEvent / endEvent | Process boundary markers | no task |
| linkEventThrow / Catch | Cross-process reference / dependency | `related_tasks` |
| intermediateCatchEvent (error / timer / message via `aef:eventDef kind=..`) | Trigger annotation on the flow (no task itself) | kind lives in the extension, never the tag; binding via `aef:eventDef binding=..` — error→`status:issues`, timer→cron/`horizon`, message→bus topic (T-204) |
| sequence flow (edge) | Ordering dependency | A→B ⇒ B depends on A |
| node documentation / annotation | Acceptance-criteria seed | ACs enriched by the agent (IW-3) |

**owner is the lane (IW-9, v1.1):** a node's `owner` MUST be its lane — there is **no** node-level `owner` override. The Lane (its `aef:laneMeta authority`) is the sole authority-of-record for who-performs, compiled via the collapse map `sovereignty→human`, `initiative→agent`, `authority→agent`, `external→no task`. Task-type (userTask vs service/scriptTask) SHOULD agree with the lane and is **presentational** where it does not; the forward-compiler emits a validation **WARNING** on the mismatch rather than refusing the diagram (O-1: lane wins, warn-not-refuse).

## 4. Reverse mapping (AEF record → rendered process map)

First target is AEF's own structured record (IW-4); arbitrary source parsing is out of scope for v1.

| AEF artifact | Rendered as |
|---|---|
| A task | Task node, typed by `workflow_type`, laned by `owner` |
| `related_tasks` / dependency | Sequence flow |
| An inception (go/no-go) | Collapsed `subProcess` w/ `aef:meta workflowType="inception"` in a sovereignty lane; go/no-go **implied at the boundary** (no child gateway — §7) |
| An arc | Collapsed subProcess containing its constituents |
| Parallel/independent tasks | parallelGateway fan-out |
| Episodic (completed order) | Left-to-right flow ordering |

## 5. Identity & round-trip — `aef:uid`

- Every node and edge MUST carry a stable `aef:uid`. It is the round-trip hinge (identity survives forward
  edits and reverse re-renders).
- **Reverse:** each rendered element MUST set `aef:uid = <task-id>` (or a deterministic hash for edges), so
  re-rendering the same record is byte-stable.
- **Forward:** a node whose `aef:uid` resolves to an existing task is a **modify** proposal; a node with no
  `aef:uid` is a **create** proposal.
- `aef:uid` is **externally assignable** — the reference editor's import path honors arbitrary `aef:uid`
  values, so a reverse renderer needs no editor change for identity.

## 6. Conformance requirements

An implementation is **v1-conformant** iff:
1. It honors the §1 two-class partition (semantic read on forward; presentational derived on reverse).
2. It emits/round-trips every frozen governance meta-key (§2) on task-like nodes.
3. It carries a stable, externally-assignable `aef:uid` on every node and edge (§5).
4. Presentational-only edits are task-graph no-ops.

The frozen governance meta-key list (§2) is machine-checked against the reference editor and bridge by
`tests/test_mapping_standard_conformance.py` (standard↔implementation parity; complements the T-060 editor↔bridge parity test).

## 7. Inception marker (G-3) — ratified v1.1

An inception is a **collapsed `subProcess`** carrying `aef:meta workflowType="inception"`, laned in a
**sovereignty** lane. It **MUST** be sovereignty-laned: a conformant inception's go/no-go boundary MUST sit in a sovereignty (human) lane, machine-checked at compile time (O-3, v1.1); `owner` derives to `human` from that lane (§3, no node override). The
go/no-go gateway is **implied at the subProcess boundary**: a conformant inception **MUST NOT** emit a child
`exclusiveGateway` (T-081 phase-1 is collapsed-only, no nesting). Members are listed in `<aef:constituents>`.
A gateway-less task-node is **not** an acceptable inception form — the lightweight inception **is** the
collapsed subProcess. Detection: a `subProcess` **with** `workflowType="inception"` ⇒ inception; **without**
⇒ ordinary composite (cf. §4). Reference fixture: `tests/fixtures/aef-bpmn/inception-gonogo.bpmn`.

---

