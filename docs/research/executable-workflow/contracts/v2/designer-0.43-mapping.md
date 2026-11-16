# Designer 0.43.0 BPMN export → EWCR contracts v2 procedure (shared contract 2)

**Task:** T-5184 · **Pairing:** shared contract 2, mapping/compatibility (T-5183; 832 T-1425) ·
**Status:** draft for 832 to check · **Worked example:** `examples-mapping/` ·
**Test:** `tests/unit/test_t5184_designer_mapping.py`

This file sits beside contracts v2 but is **not part of the frozen set**. It is not listed in
`MANIFEST.yaml`, and no contracts v1/v2 file was changed to write it (same standing as
`validator-refusal-mapping.md`, shared contract 3).

## 1. Scope and versions

| Side | Artifact | Version | sha256 |
|---|---|---|---|
| Designer (832) | `vendor/designer/aef-workflow-designer-0.43.0.html` (`APP_VERSION = '0.43.0'`, line 14073) | 0.43.0 | `8511974771820287731f8c5a11033feba573a45c9446678c7f02aed12acb287f` |
| Runtime contract (AEF) | `contracts/v2/procedure.schema.json` (`"version": 1`) | contracts v2, schema_version 1 | `ac9aaefc2495b67679c81b77d74cd622a134c82df5503d84e1e31fed5752edf5` (MANIFEST.yaml) |

The mapping is **one-way and import-only**. It reads the BPMN 2.0 XML that the designer's Save
writes (`buildBpmnXml`, line 14172; per-node extensions from `aefExtensionXml`, line 13758) and
produces a procedure with `status: draft`. Architecture §"Shared versioned contracts" items 2
and 5 apply: a designer export is a **proposal**. It never ratifies and never sets lifecycle
fields. The reverse direction (procedure → BPMN) is covered only as a round-trip check (§5).

All line numbers below are in `aef-workflow-designer-0.43.0.html` and are approximate. Each is
paired with a search string that finds it.

**The rule in one sentence.** The procedure keeps what the runtime needs to execute and judge a
step. Identity is `aef:uid`. Kind comes from the BPMN tag (or `nodeKind`). The outcome, the typed
I/O names, the catalogue references, the guards and the decision map are taken from the export.
Everything else is layout, prose or design-time governance. It stays in the BPMN, which remains
the authoring source, and none of it enters the procedure.

## 2. Table A: what 0.43.0 emits → procedure field

Outcomes: **mapped** (field named), **check** (read and used to refuse, not stored), **lost**
(read and dropped, nothing in the procedure depends on it), **refused** (import fails: the
procedure cannot express it, and dropping it would change behaviour).

### 2.1 Document and process level

| Emitted | Where in 0.43.0 | Procedure | Outcome / what is lost |
|---|---|---|---|
| `bpmn:definitions` @id, @targetNamespace, @exporter, xmlns:bpmn/bpmndi/dc/di/aef | `buildBpmnXml` first lines; `AEF_TARGET_NS` (14892) | none | **check**: `exporter="aef-workflow-designer"` and the aef namespace `http://anchorpoint.framework/aef/extensions` must be present. Ids are lost (regenerated from `workflowMeta/@id`, `exportIdsOf` 14895). |
| Kept foreign root attributes and the document comment | `rootKept`, `docComment`, `safeCommentData` | none | **lost** |
| `bpmn:collaboration`, `bpmn:participant` (the pool) | `<bpmn:collaboration id=` | none | **lost** (the pool name and id). |
| Other participants, `bpmn:messageFlow`, other `bpmn:process`, `bpmn:message` (kept from an import) | `captureCollaboration`, `s.collab` | none | **refused**: a second process or a message flow is behaviour the procedure cannot express. |
| `bpmn:process` @id, @isExecutable | `<bpmn:process id=` | none | **lost** (@id). **check**: `isExecutable` must not be `"false"`. |
| `aef:workflowMeta` @id | `<aef:workflowMeta ` | `id` | **mapped** verbatim. Refused if it does not match `^[a-z][a-z0-9-]*$`. |
| `aef:workflowMeta` @version (designer default `'1'`) | same line, `wm.version \|\| '1'` | `version` | **mapped**: `X.Y.Z` verbatim; a bare integer `N` becomes `N.0.0`; anything else is refused. *Inferred, Q2.* |
| `aef:workflowMeta` @kind | `wm.kind` | none | **check**: must be `work-plan`. `documentation` or absent is refused: an illustrative map is not a procedure (T-213/T-875). |
| `aef:workflowMeta` @uuid, @schemaVersion, @title, @description, @source, @tier_default, @pageWidth, @laneProvenance, @poolProvenance | `wmAttrs` | none | **lost**. The procedure has no title or description field. |
| Process-level `aef:meta` (mappingVersion, `aef:prefixes`), other tools' process extensions | `procMetaKept`, `pk.procExt` | none | **lost**. The prefixes only qualify io `fieldRef`s, which are lost too (2.3). |
| Process documentation, data objects/stores, `textAnnotation`, `association`, `group`, categories, event roots | `pk.procDocs`, `s.dataKept`, `pkOut.artifacts`, `pk.categories`, `s.eventRoots` | none | **lost** (documentation and annotations; they have no runtime meaning). |
| `bpmn:laneSet`, `bpmn:lane` @id @name, `bpmn:flowNodeRef` | `<bpmn:lane id=` | none | **lost**, used only as a check (next row). |
| `aef:laneMeta` @authority, @authoringDefault, @abbr, @height | `<aef:laneMeta ` | none | **check**: a node in a lane with `authority="sovereignty"` must map to `human_gate`; otherwise the import is refused. Abbr and height are lost. *Inferred, Q5.* |
| `bpmndi:BPMNDiagram` and everything in it (`BPMNShape`, `dc:Bounds`, `BPMNEdge`, `di:waypoint`) | `<bpmndi:BPMNDiagram` | none | **lost** (layout). |

### 2.2 Flow nodes (the BPMN tag, `TYPE_TAG` line 13724)

| Designer type → tag | Procedure `kind` | Notes |
|---|---|---|
| `startEvent` → `bpmn:startEvent` | `gateway`; its uid is `start_node` | Exactly one is required, otherwise refused. A pass-through node keeps every sequenceFlow as one edge. |
| `endEvent` → `bpmn:endEvent` | `gateway`; its uid is in `terminal_nodes` | At least one is required. Same precedent as `done` in `examples/procedure-human-script-human.json`. |
| `userTask` → `bpmn:userTask` | `human_gate` | `human_decision_map` is required (2.4). |
| `scriptTask` → `bpmn:scriptTask` | `script` | `action_ref` and `capability_profile_ref` are required by the schema (2.3); without them the import is refused. |
| `serviceTask` → `bpmn:serviceTask` | `agent_prompt` when `aef:meta/@agentType` is set, else `service` | *Inferred, Q3.* |
| `exclusiveGateway` → `bpmn:exclusiveGateway` | `gateway` | Branch conditions become edge `guard`s (2.4). |
| `parallelGateway` → `bpmn:parallelGateway` | none | **refused**. v2 has no fork/join semantics, and a `gateway` would read as exclusive. *Q4.* |
| `linkEventThrow` → `bpmn:intermediateThrowEvent` with `aef:link @workflowRef/@targetWorkflow` | `call_workflow` | *Inferred, Q6.* A same-document link pair (only `@linkId`) is **refused**: it is a drawing connector, not a step. |
| `linkEventCatch` → `bpmn:intermediateCatchEvent` with `aef:link` | none | **refused** under the same rule as link throws (Q6). |
| `eventMessage` → `bpmn:intermediateCatchEvent` + `aef:eventDef kind="message" binding=` (in flow) | `wait_event` | `binding` (bus topic) is **lost**. The procedure has no event-name field. *Q7.* |
| `eventTimer` → same, `kind="timer"` (in flow) | `wait_event` | `timerSpec` is lost. *Q7.* |
| `eventError` → same, `kind="error"` (in flow) | none | **refused**. v2 has no error-path semantics. |
| Any typed event with `hostRef` → `bpmn:boundaryEvent attachedToRef= cancelActivity=` | none | **refused**, except a timer boundary with no outgoing flow, whose `binding` maps to the host's `timeout` when it is an ISO 8601 duration. *Q7.* |
| `subProcess` (collapsed) → `bpmn:subProcess` | none | **refused**. v2 has no nesting; `call_workflow` names a separate procedure. |
| Foreign tags kept verbatim (`task`, `sendTask`, `receiveTask`, `manualTask`, `businessRuleTask`, …; `n.foreignTag`) | none | **refused**. Unknown semantics. |
| `@nodeKind` on `aef:meta` (carried key, see 2.3) | overrides the kind above | The only way to produce `command` or `compensate`. *Proposed carrier, Q1.* |

### 2.3 Per-node attributes and extensions (`aefExtensionXml`, line 13758)

| Emitted | Procedure | Outcome / what is lost |
|---|---|---|
| `@id` (displayId `<lane abbr>_<seq>_<slug>`, `computeDisplayId` 2407) | none | **lost**. Used only to resolve `sourceRef`/`targetRef`. It changes when a node moves, so it is not identity. |
| `@name` | none | **lost**. The procedure has no label field. |
| `bpmn:documentation` (@id, @textFormat) | none | **lost** |
| `bpmn:incoming` / `bpmn:outgoing` | none | **lost** (redundant with the sequenceFlows). |
| `aef:uid @value` (`n_` + 8 hex, `generateUid` 2257) | `nodes[].uid` | **mapped** verbatim. It is the stable identity; it must match `^[a-z][a-z0-9_]*$`, which generated uids do. Missing or duplicated → refused. |
| `aef:position @x @y` | none | **lost** (layout). |
| `aef:meta` named keys (`metaKeys`, line 13777): `tier`, `agentType`, `decisionOwner`, `triggeredBy`, `terminalKind`, `state`, `note`, `softFail`, `section`, `guard`, `external`, `exitCode`, `autoTrigger`, `trigger`, `gatewayKind`, `gate`, `scopeOf`, `horizon`, `workflowType`, `owner`, `authority` | none, except `state` (next row) and `agentType` (2.2) | **lost**: design-time governance and prose. `authority` and `owner` are re-checked through the lane (2.1). `aef:meta/@guard` is **not** an edge guard (Q8). |
| `aef:meta @state` on an `endEvent` | `nodes[].outcome` when `@outcome` is absent | **mapped** (fallback). |
| `aef:meta` carried keys (any other scalar, sorted after the named keys: `carriedKeys`, line 13848; e.g. `determinism`, `sideEffect`) | see the next six rows; anything else is none | Carried keys not named below are **lost**. |
| `aef:meta @outcome` | `nodes[].outcome` | **mapped**. Required: a node with no `@outcome` (and no end-event `@state`) is refused. *Proposed carrier, Q1.* |
| `aef:meta @actionRef`, `@capabilityProfileRef`, `@executionProfileRef`, `@compensationRef` | `action_ref`, `capability_profile_ref`, `execution_profile_ref`, `compensation_ref` | **mapped** verbatim (catalogue refs, never paths). *Proposed carriers, Q1.* |
| `aef:meta @timeout` (ISO 8601 duration), `@maxAttempts` (0–10) | `timeout`, `retry.max_attempts` | **mapped**. *Proposed carriers, Q1.* |
| `aef:endpoint` (text) | none | **lost**, and deliberately **not** used as `action_ref`: it is a shell string or path (`fw report write …`), and the schema forbids that in a ref (arch §6.2.1). |
| `aef:contextReads @paths` | `context_selectors` (split on `,`, trimmed) | **mapped**. *Inferred, Q9.* |
| `aef:artifactsWrites @paths` | none | **lost**. The typed outputs carry what the runtime checks. |
| `aef:decisionInput` (text) | none | **lost**. The decision is carried by the edge guards. |
| `aef:decisionOutputs` (comma list) | the keys of `human_decision_map` | **mapped** on `userTask` (2.4). On an `exclusiveGateway` it is **lost** (the guards carry the branches). |
| `aef:link @workflowRef @name @targetWorkflow @linkId` | `call_workflow` (`@workflowRef`/`@targetWorkflow`) | See 2.2. The procedure has no field that names the called workflow, so the name is **lost**. *Q6.* |
| `aef:eventDef @kind @binding` (`eventDefXml`, 14696) | kind (2.2) | `@binding` is **lost**, except for a boundary timer (2.2). |
| `aef:boundaryPos @value` | none | **lost** (layout). |
| `aef:io` / `aef:input @name @type @required` (+ extra attributes) | `inputs[]` = the `@name`s in order | `@type`, `@required` and extra attributes are **lost**. *Q10.* |
| `aef:io` / `aef:output @name @type` | `outputs[]` = the `@name`s in order | `@type` is **lost**. |
| `aef:field` (+`aef:when`), `aef:expect` (+`aef:value`), `aef:example` inside an io | none | **lost** (the field-catalog detail; 832 T-1302/T-1365). |
| `aef:emits/aef:emit @value`, `aef:compensates/aef:compensate @ref` (`STRUCT_LIST_KEYS`, 2631) | none | **lost**. A node that compensates becomes `compensate` only through `@nodeKind`. |
| `aef:aggregation`, `aef:multiInstance` | none | **refused**: v2 has no fan-out. |
| `aef:timer` (dict) | none | **lost**. *Q7.* |
| `aef:constituents/aef:constituent` | none | Only on `subProcess`, which is refused. |
| Unknown `aef:` children kept by the designer (`aefKept`, `nodeAefKeptXml` 13663), other tools' extensions, `x832:origin @originalId` (`ORIGIN_NS` 13655) | none | **lost** |
| `bpmn:linkEventDefinition`, native `*EventDefinition`s | none | Link: see 2.2. Native definitions on a plain event → **refused**. |
| Data associations, `ioSpecification`, `property` kept per node | none | **lost** |

### 2.4 Sequence flows (`edgeLines` in `buildBpmnXml`)

| Emitted | Procedure | Outcome / what is lost |
|---|---|---|
| `bpmn:sequenceFlow @sourceRef @targetRef` | `edges[].from` / `to` = the target nodes' `aef:uid` | **mapped**. One flow becomes one edge. A dangling ref is refused. |
| `@id` (`flow_<seq>`, `computeEdgeDisplayId` 2429), `aef:uid` (`e_` + 8 hex) | none | **lost**. Procedure edges have no id. *Q11.* |
| `@name` | `human_decision_map[name] = to`, on a `userTask` source whose `aef:decisionOutputs` lists that name | **mapped**. Every decision label must match exactly one outgoing flow name; otherwise refused. On other sources `@name` is **lost**. |
| `bpmn:conditionExpression` (text; @language, @id) | `edges[].guard` (trimmed text, ≤ 300 chars) | **mapped**. @language and @id are **lost**. Whether the text is a lawful typed expression (arch §6.1) is AEF validation, not this mapping. |
| `aef:anchors`, `aef:loopDetour`, `aef:forceStraight`, `aef:routingHint`, `aef:routing/aef:waypoint` | none | **lost** (layout). |
| Kept documentation, other tools' extensions, kept children, `x832:origin` | none | **lost** |
| (nothing) | `edges[].required_outputs` | **No 0.43.0 source.** It stays absent. 0.43.0 drops unknown `aef:` children on a flow at re-save (`elementKept`, 14674, keeps only non-`aef:` extensions), so this needs a carrier. *Q12.* |

## 3. Table B: every procedure.schema.json field → its source

Required fields first.

| Field | Required | Source |
|---|---|---|
| `id` | yes | `aef:workflowMeta/@id` |
| `version` | yes | `aef:workflowMeta/@version` (2.1 rule) |
| `status` | yes | **Set by AEF**: always `draft` at import. Later values are AEF lifecycle transitions (arch §7.1): `validated` after AEF validation, `proposed` when submitted for ratification, `ratified` at the human ratification step, `deprecated` when a successor is ratified. Never read from the export. |
| `content_hash` | yes | **Computed by AEF** at import (§4). Recomputed at every status transition, and must be unchanged at ratification. |
| `start_node` | yes | `aef:uid` of the single `bpmn:startEvent` |
| `terminal_nodes` | yes | `aef:uid` of every `bpmn:endEvent` |
| `nodes` | yes | flow nodes, 2.2 |
| `nodes[].uid` | yes | `aef:uid/@value` |
| `nodes[].kind` | yes | BPMN tag (2.2), or `aef:meta/@nodeKind` |
| `nodes[].outcome` | yes | `aef:meta/@outcome`; for an `endEvent`, `aef:meta/@state` as fallback |
| `edges` | yes | `bpmn:sequenceFlow`, 2.4 |
| `edges[].from` / `to` | yes | `@sourceRef` / `@targetRef` resolved to `aef:uid` |
| `ratification` (`actor`, `ts`, `decision_ref`) | when ratified/deprecated | **Set by AEF at ratification**: the human decision recorded through AEF's authority (Watchtower decision → ratification contract, item 5). `actor.kind` must be `human`. Never from the export. |
| `successor_version` | when deprecated | **Set by AEF at deprecation**, when the next version is ratified. |
| `nodes[].inputs` / `outputs` | no | `aef:io/aef:input/@name` / `aef:output/@name` |
| `nodes[].action_ref` | `script`, `command` | `aef:meta/@actionRef` (Q1) |
| `nodes[].capability_profile_ref` | `script`, `command` | `aef:meta/@capabilityProfileRef` (Q1) |
| `nodes[].execution_profile_ref` | no | `aef:meta/@executionProfileRef` (Q1) |
| `nodes[].compensation_ref` | no | `aef:meta/@compensationRef` (Q1) |
| `nodes[].context_selectors` | no | `aef:contextReads/@paths` (Q9) |
| `nodes[].timeout` | no | `aef:meta/@timeout`, or a boundary timer (2.2) (Q1, Q7) |
| `nodes[].retry.max_attempts` | no | `aef:meta/@maxAttempts` (Q1) |
| `nodes[].human_decision_map` | `human_gate` | `aef:decisionOutputs` + outgoing flow `@name`s (2.4) |
| `edges[].guard` | no | `bpmn:conditionExpression` text |
| `edges[].required_outputs` | no | none in 0.43.0 (Q12) |

## 4. content_hash: the bytes

Both sides must get the same value from the same definition. The bytes are therefore **not** the
BPMN file, which changes when a node is dragged, flows are reordered, or a note is edited.
The hash is taken over the **mapped procedure**:

1. Take the procedure object and remove `status`, `content_hash`, `ratification` and
   `successor_version`. These are AEF lifecycle fields, so ratifying or deprecating a version
   does not change its hash.
2. Sort `nodes` by `uid`, `edges` by (`from`, `to`, `guard` or `""`), and `terminal_nodes`
   lexically. Every other array keeps its mapped order (io order is the order of `aef:input`
   and `aef:output` in the export).
3. Serialise as canonical JSON: keys sorted at every level, no whitespace (`,` and `:`
   separators), UTF-8, non-ASCII characters literal. For this schema it is the same as
   RFC 8785 (JCS), because the only number is the integer `retry.max_attempts`. In Python:
   `json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")`.
4. `content_hash = "sha256:" + hex(sha256(bytes))`.

The test pins this. Moving a node in the BPMN leaves the hash unchanged, as does reordering
nodes or edges or adding a ratification. Changing an outcome changes it.

The designer can compute the same value by running this mapping. If it sends the hash alongside
the export (architecture "Designer authors/exports proposed definition + content hash"), AEF
recomputes it and refuses a mismatch. AEF also records `sha256` of the received BPMN bytes as
the *source* hash, for read-back. That hash names the file, not the procedure. *Q13.*

Note: the `content_hash` in `examples/procedure-human-script-human.json` (v1/v2) is a fixture
value and was not produced by this rule. This document does not change it.

## 5. Round-trip

**BPMN → procedure → BPMN is not lossless, by design.** Everything marked *lost* in §2 is
dropped: names, documentation, lanes, layout, governance meta, io types, endpoints. The BPMN stays
the authoring source and the procedure is its executable projection. AEF keeps the source
hash (§4) so it can always say which file a procedure came from.

**Procedure → BPMN → procedure is lossless for the hashed content, with one exception.**

| Survives | How it is carried in 0.43.0 |
|---|---|
| `id`, `version` | `aef:workflowMeta @id @version` |
| node `uid`, `kind`, `outcome` | `aef:uid`; tag + `aef:meta @nodeKind`; `aef:meta @outcome` |
| `inputs`, `outputs` | `aef:io` (written with `type="string"`; type is ignored on the way back) |
| `action_ref`, profile refs, `compensation_ref`, `timeout`, `retry` | carried `aef:meta` keys (T-570 carriage keeps unknown scalars) |
| `context_selectors` | `aef:contextReads @paths` (joined with `, `) |
| `human_decision_map` | `aef:decisionOutputs` + flow `@name`s |
| `start_node`, `terminal_nodes`, edges, `guard` | start/end events, sequenceFlows, `conditionExpression` |

| Does not survive | Why |
|---|---|
| `edges[].required_outputs` | No 0.43.0 carrier (2.4, Q12). A procedure that has them is **not** round-trippable through 0.43.0. |
| `status`, `content_hash`, `ratification`, `successor_version` | Never in the BPMN, on purpose: a re-imported procedure is `draft` again with the **same** `content_hash`. That equality is the round-trip test. |
| A procedure whose start node is not a pass-through `gateway`, or whose terminal is not a `gateway` | 0.43.0 needs start and end events. Such a procedure is written with added start/end gateways, so it does not come back byte-equal. *Q14.* |
| `kind` `wait_event` (timer vs message), `call_workflow` target | The kind survives through `@nodeKind`, but the target workflow or event name is not a procedure field, so it cannot be produced. |

## 6. Compatibility rule

A mapping document is identified by the pair **(designer version, contracts version)**. This
one is `designer 0.43.0 → contracts v2 (procedure.schema.json schema_version 1)`.

- **Designer version D maps to contracts v2 only if a mapping document names D.** AEF refuses an
  export whose designer build has no mapping document. The build is identified by
  `exporter="aef-workflow-designer"` plus the artifact sha256 of the delivered build
  (`policy/designer-pin.yaml`), because 0.43.0 writes no version number into the XML. *Q15.*
- **Designer bump (0.43.0 → 0.44.0 or later).** 832 states whether the export changed: elements,
  attributes, `metaKeys`, `NODE_AEF_READ`, carriage, the flow keep rules. If nothing in §2
  changed, AEF adds a one-line row naming the new version and sha256 and re-runs the example. If
  anything changed, a new mapping document `designer-<new>-mapping.md` is written, the example
  is re-exported, and the test is re-run against it. The old document stays for the old build.
- **Contracts bump (v2 → v3), or any change to `procedure.schema.json`.** Write a new mapping
  document for the pair, rebuild Table B from the new schema, re-validate every example against
  the new schema, and recompute `content_hash` values if the hashed field set changed. A
  procedure ratified under v2 is not migrated in place. It keeps its v2 hash. A v3 version is a
  new procedure version, ratified again (§7.1: a change to a ratified procedure is a new
  version).
- **A change to the §4 hash rule** is a contracts bump, never a mapping edit. Every stored hash
  depends on it.
- Either side's change to this mapping needs the joint compatibility review the architecture
  names, and human-owned ratification.

## 7. Open questions for 832

Everything marked *Inferred* or *Proposed carrier* above. These are the rows 832 should look
at hardest.

- **Q1 (proposed carriers).** 0.43.0 has no field for `outcome`, `actionRef`,
  `capabilityProfileRef`, `executionProfileRef`, `compensationRef`, `timeout`, `maxAttempts` or
  `nodeKind`. This mapping uses them as **carried `aef:meta` scalars**, which 0.43.0 already
  writes verbatim (T-570) without a contract change. Are these names acceptable? Does 832 prefer
  them offered in the panel, as T-618 did for `determinism`?
- **Q2.** Is `workflowMeta/@version="1"` → `1.0.0` the right reading, or should the designer
  write semver?
- **Q3.** Is `serviceTask` + `agentType` → `agent_prompt`, else `service`, how 832 means it?
- **Q4.** Refuse `parallelGateway` under v2, or does 832 expect AEF to model fork/join?
- **Q5.** The sovereignty-lane check (a node in a `sovereignty` lane must be a `human_gate`):
  does it match 832's IW-9 collapse (`AUTHORITY_OWNER`), or is it too strict for, say, a
  start event drawn in the human lane?
- **Q6.** Cross-workflow link throw → `call_workflow`? Same-document link pairs refused?
- **Q7.** In-flow timer and message catches → `wait_event`; error events and boundary events
  refused, except a flowless boundary timer → host `timeout`. Is the `timerSpec` format an
  ISO 8601 duration?
- **Q8.** `aef:meta/@guard` on a node: what is it? This mapping ignores it and uses only
  `conditionExpression`.
- **Q9.** `aef:contextReads` paths → `context_selectors` as-is (they may contain `${…}`)?
- **Q10.** io `@type`/`@required` are dropped because procedure io is names only. Should v3
  type the io, given that 832's field catalog already has the types?
- **Q11.** Flow `aef:uid` is lost because procedure edges have no id. Does 832 need edge identity
  back from AEF (e.g. for runtime projection, shared contract 4)?
- **Q12.** `required_outputs` has no carrier, and an unknown `aef:` child on a flow is dropped
  at re-save (`elementKept` keeps only non-`aef:` extensions). Options: (a) 832 adds a flow-level
  `aef:requiredOutputs` it reads and writes; (b) a non-`aef:` namespace element, which 0.43.0
  already keeps verbatim; (c) leave it AEF-only. Which one?
- **Q13.** Will the designer send a `content_hash` with the export, computed by this rule, or
  should AEF compute it alone?
- **Q14.** Start and end events become pass-through `gateway` nodes, so each sequenceFlow stays one
  edge. The alternative is to drop them and point `start_node` at the first step. Preference?
- **Q15.** Could the export carry its designer version (e.g. `exporterVersion` on
  `bpmn:definitions`, a standard BPMN attribute) so the mapping version can be read from the
  file instead of from the delivered build's sha256?

## 8. Worked example

`examples-mapping/human-script-human.bpmn` was **built by hand** in the exact shape
`buildBpmnXml` writes, not saved from the designer. `vendor/` has no 0.43.0 sample export. The
`.context/designer/` and `tests/fixtures/corpus-832-goldens/` files come from older builds. It
passes 832's own validator: `python3 vendor/designer/validate-workflow-0.43.0.py` returns
`VALID … no findings`. It is the human → script → human procedure of
`examples/procedure-human-script-human.json`, drawn in the designer's default lanes. Its reject
branch loops back to the first gate.

`examples-mapping/human-script-human.procedure.json` is what this mapping produces from it
(`status: draft`). It validates against `procedure.schema.json`. The test's reference mapper,
which implements §2–§4 for the element subset the example uses, reproduces it exactly. Dropped
in this example: names, lanes, positions and DI, `aef:endpoint` on the script, `determinism`,
`tier`, `authority`, `triggeredBy`, `terminalKind`, io types, flow ids and uids.
