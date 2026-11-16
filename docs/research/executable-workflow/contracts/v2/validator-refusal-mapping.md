# Validator codes ↔ runtime refusal codes (shared contract 3)

**Task:** T-5189 · **Pairing:** shared contract 3, validation/refusal (T-5183; 832 T-1425) ·
**Status:** draft for 832 to check · **Machine-readable twin:** `validator-refusal-mapping.yaml`

This file sits beside contracts v2 but is **not part of the frozen set**: it is not listed in
`MANIFEST.yaml`, and no contracts v1/v2 file was changed to write it.

## What the relation is

The designer's validator (`vendor/designer/validate-workflow-0.43.0.py`, 832's, pinned at
0.43.0) checks a **map** at design time. The runtime refuses a **proposal** against a live
instance and writes a refusal record (`refusal.schema.json`, v2). The two never meet as
records: a validator finding has no instance, no requester and no ledger position, so it can
never be a refusal record, and a refusal record can never be produced by the validator.

The relation between them is **prevention**. A validator code *prevents* a reason_code when
the finding flags a defect in the map which, if the map were ratified and run, would be a
cause of that refusal. Fixing the finding removes that cause before anything runs.

- **runtime-only**: no defect in a map can cause this refusal; only something that happens
  at run time can (a requester, a delivery, a cancellation, a binding, a clock).
- **design-only**: the finding is about the map's form, layout or documentation and is not
  a cause of any runtime refusal. It still matters to the author; it just has no runtime
  counterpart.
- A reason_code can be both prevented and still raised at run time for other causes. The
  "Why" column names the part that stays runtime-only.

Coverage: 18 reason_codes (the v2 enum, `privilege_exceeds_profile` included) and every
code the validator can emit: 38 `E-`, 40 `W-`, and the 2 `I-` (info) codes, which the
validator emits too and are listed so the set is complete. Codes are emitted as literals
only (checked: every `err`/`warn`/`info` call passes a string constant); `--strict` raises
some `W-` codes to errors but keeps their names, so it adds no codes.

Rows marked **\*** are **inferred**: the source does not state the link, and I reasoned it
from what the code checks and what the refusal guards. They are listed at the end and are
the rows 832 should look at hardest.

## Table A — runtime reason_codes

| reason_code | What it refuses | Prevented by | Why |
|---|---|---|---|
| `unratified_procedure` * | instance creation from a procedure no human has ratified | `E-WORKFLOW-KIND`, `E-XML-WORKFLOW-KIND`, `W-XML-NO-WORKFLOWMETA` | §13 #1 (architecture-c9070637.md:911). Only the kind marker is design-time: a map whose kind is invalid or undeclared cannot be told apart from documentation, so the runtime must treat it as not a ratifiable procedure. A valid executable map is still unratified until a human ratifies it; that refusal stays runtime-only. |
| `unresolved_reference` | a reference that does not resolve (action, profile, node, field, compensation) before dispatch | `E-EDGE-DANGLING`, `E-NODE-LANE`, `E-SCOPEOF-DANGLING`, `E-UID-DUP`, `E-XML-FLOW-DANGLING`, `E-XML-ID-DUP`, `E-XML-IO-PREFIX-UNDECLARED`, `E-XML-LANEREF-DANGLING`, `E-XML-UID-DUP`, `W-XML-GW-DEFAULT-NOT-OWN`, `W-XML-IO-FIELD-UNKNOWN`, `W-XML-IO-MATCH-UNRESOLVED` | §13 #2 (architecture-c9070637.md:912); evidence-and-idempotency.md:164 (compensation on a node that declares none). The validator catches dangling or ambiguous references inside the map and against the field catalog. It does not check action or capability-profile references, the main subject of §13 #2; those stay runtime-only. |
| `human_gate_skipped` * | an actor passing a human gate without an admitted human envelope | `E-AUTHORITY`, `E-INCEPTION-NOT-SOVEREIGN`, `E-META-AUTHORITY`, `E-NODE-LANE`, `E-XML-AUTHORITY`, `E-XML-LANE-AUTHORING-DEFAULT`, `E-XML-META-AUTHORITY`, `E-XML-NODE-UNASSIGNED`, `W-LANE-NO-OWNER`, `W-TYPE-LANE-MISMATCH`, `W-XML-LANE-NO-AUTHORITY` | §13 #3 (architecture-c9070637.md:913); task-lifecycle-contract.md:102. A step with no derivable authority must be treated as gated, so an agent completing it is refused; the authority findings remove that cause. An agent deliberately passing a correctly declared gate is runtime-only. |
| `scope_mismatch` | work outside the pinned repository/worktree, or a bound task no longer in active/ | runtime-only | §13 #4 (architecture-c9070637.md:914); task-lifecycle-contract.md:35-38; accepted-scenarios.md:47. The map has no repository, worktree or task binding to check. |
| `missing_typed_input` | advancement when a declared typed input is absent, whatever the worker claims | `E-XML-IO-EXPECT-CONTRADICTS`, `E-XML-IO-MATCH-MISSING`, `W-IO-INPUT`, `W-XML-IO-FIELD-ENTITY`, `W-XML-IO-INCOMPLETE` | §13 #5 (architecture-c9070637.md:915). W-IO-INPUT finds a required input with no upstream producer; the io findings find inputs that are untyped, sourceless, of another object or unsatisfiable. A worker that simply fails to produce a declared output is runtime-only. |
| `unmeasured_component_scope` | treating unmeasured component scope as zero impact | runtime-only | §13 #6 (architecture-c9070637.md:916). The validator has no component-scope model; aef.constituents is composite-node metadata, not a Component Fabric measurement. |
| `duplicate_delivery` | a second delivery of an already-consumed attempt or result | runtime-only | §13 #7 (architecture-c9070637.md:917); evidence-and-idempotency.md:127,152. Delivery is a runtime event; a map cannot contain it. |
| `capability_unsupported` * | a step the bound provider cannot perform (no silent substitution) | `E-NODE-TYPE`, `E-XML-NODE-TYPE` | §13 #8 (architecture-c9070637.md:918). Only the node-type vocabulary is design-time: an element no executor knows can never be performed. Provider capability itself is resolved at binding time and is runtime-only. |
| `direct_state_mutation` | state changed outside an admitted envelope (agent edit, Watchtower write, deadline replay) | runtime-only | §13 #11, #17, #20 (architecture-c9070637.md:921,927,930); refusal-threat-matrix.md ZA-3, ZA-5. A map describes no state writes. |
| `ambiguous_identity` | a request carrying only shared host identity | runtime-only | §13 #12 (architecture-c9070637.md:922). Requester identity exists only at run time. |
| `task_hash_drift` | advancement after the bound task changed between gates or during an attempt | runtime-only | §13 #13 (architecture-c9070637.md:923); accepted-scenarios.md:46 (N-1). The task binding and its hash exist only at run time. |
| `policy_or_capability_drift` | an attempt whose policy or capability changed since ratification | runtime-only | §13 #15 (architecture-c9070637.md:925). Drift is a difference between two runtime moments; one map has no second moment. |
| `bypass_input` | an env flag or --force-equivalent presented to cross the runner boundary | runtime-only | §13 #16 (architecture-c9070637.md:926); task-lifecycle-contract.md:106. Inputs are presented at run time. |
| `cancellation_in_effect` | advancement after the instance or bound task was cancelled | runtime-only | §13 #18 (architecture-c9070637.md:928); accepted-scenarios.md:45 (N-1). Cancellation is a runtime event. |
| `stale_position` * | a proposal made against a ledger position that is no longer the head (the loser of a race) | `W-GW-AMBIGUOUS`, `W-XML-GW-AMBIGUOUS`, `W-XML-GW-BRANCH-UNCONDITIONED` | §13 #19 (architecture-c9070637.md:929); evidence-and-idempotency.md:95,144. An exclusive gateway with more than one unconditioned branch lets two proposals advance one position along different edges; one of them must lose. Races between actors are runtime-only. |
| `command_substitution` | an action that escapes its registered argv to a shell string | runtime-only | §13 #4, #16 (architecture-c9070637.md:914,926); refusal-threat-matrix.md CL-6, MS-5. The validator does not read script contracts or arguments. |
| `deadline_expired` | advancement after a recorded deadline passed | runtime-only | §13 #17 (architecture-c9070637.md:927). Deadlines are ledgered runtime events; the map declares none the validator checks. |
| `privilege_exceeds_profile` | a resolved secret binding that can do more than the node's capability profile allows | runtime-only | N-2 (accepted-scenarios.md:86). Bindings resolve at run time; the validator reads no capability profile or binding. |

## Table B — validator codes

| Code | Rule | Prevents |
|---|---|---|
| `E-LOAD` | the file cannot be found or read | design-only |
| `E-YAML-PARSE` | the YAML does not parse | design-only |
| `E-XML-PARSE` | the XML does not parse | design-only |
| `E-NOT-MAPPING` | the YAML top level is not a mapping | design-only |
| `E-TOPLEVEL-MISSING` | a required top-level key is missing | design-only |
| `E-XML-STRUCTURE` | no <bpmn:definitions> containing a <bpmn:process> | design-only |
| `E-WORKFLOW-KIND` * | workflow kind is not in the closed kind vocabulary (YAML) | `unratified_procedure` |
| `E-XML-WORKFLOW-KIND` * | workflow kind is not in the closed kind vocabulary (XML) | `unratified_procedure` |
| `W-XML-NO-WORKFLOWMETA` * | no <aef:workflowMeta>: no id of its own and no kind | `unratified_procedure` |
| `E-LANES-EMPTY` | no lane declared (YAML) | design-only |
| `E-XML-LANES-EMPTY` | no <bpmn:lane> declared (XML) | design-only |
| `E-LANE-FIELD` | a lane is not a mapping or misses a required field | design-only |
| `E-NODE-FIELD` | a node is not a mapping or misses a required field | design-only |
| `E-EDGE-FIELD` | an edge is not a mapping or misses a required field | design-only |
| `E-ABBR-DUP` | two lanes share an abbreviation (YAML) | design-only |
| `E-XML-ABBR-DUP` | two lanes share an abbreviation (XML) | design-only |
| `E-AUTHORITY` | a lane's authority is not in the authority vocabulary (YAML) | `human_gate_skipped` |
| `E-META-AUTHORITY` | a node's own aef.authority is not in the authority vocabulary (YAML) | `human_gate_skipped` |
| `E-XML-AUTHORITY` | a lane's authority is not in the authority vocabulary (XML) | `human_gate_skipped` |
| `E-XML-META-AUTHORITY` | a node's own authority is not in the authority vocabulary (XML) | `human_gate_skipped` |
| `E-XML-LANE-AUTHORING-DEFAULT` | a lane's authoringDefault is not in the authority vocabulary | `human_gate_skipped` |
| `E-INCEPTION-NOT-SOVEREIGN` | an inception does not carry sovereignty authority | `human_gate_skipped` |
| `E-XML-NODE-UNASSIGNED` | a flow node is in no lane, so it has no authority-of-record | `human_gate_skipped` |
| `W-XML-LANE-NO-AUTHORITY` | a lane declares no authority, so its tasks' owner cannot be derived | `human_gate_skipped` |
| `W-LANE-NO-OWNER` | a lane's authority names no owner, so the task has no derivable owner | `human_gate_skipped` |
| `W-TYPE-LANE-MISMATCH` * | the node type implies a performer the lane's authority contradicts (lane wins) | `human_gate_skipped` |
| `W-XML-AUTHORITY-DEFAULT-MISMATCH` | a node's authority overrides its lane's authoringDefault (recorded, legitimate) | design-only |
| `E-NODE-TYPE` * | unknown node type (YAML) | `capability_unsupported` |
| `E-XML-NODE-TYPE` * | unknown flow-node element (XML) | `capability_unsupported` |
| `E-NODE-LANE` | a node's lane does not match any lane id | `unresolved_reference`, `human_gate_skipped` |
| `E-UID-DUP` * | a uid is used more than once (YAML) | `unresolved_reference` |
| `E-XML-ID-DUP` * | a bpmn:id is not unique | `unresolved_reference` |
| `E-XML-UID-DUP` * | an aef:uid is not unique | `unresolved_reference` |
| `E-EDGE-DANGLING` | an edge endpoint does not resolve to a node uid | `unresolved_reference` |
| `E-XML-FLOW-DANGLING` | a sequence-flow endpoint does not resolve to a flow node | `unresolved_reference` |
| `E-XML-LANEREF-DANGLING` | a lane's flowNodeRef does not resolve to a flow node | `unresolved_reference` |
| `E-SCOPEOF-DANGLING` | aef.scopeOf does not resolve to a node uid | `unresolved_reference` |
| `E-SCOPEOF-SELF` | aef.scopeOf references the node itself | design-only |
| `W-SCOPEOF-TYPE` | aef.scopeOf on a node that is not a subProcess | design-only |
| `E-CONST-SHAPE` | aef.constituents is not a non-empty list of {id, name, ref?} | design-only |
| `E-CONST-DUP` | a constituent id is duplicated within one node | design-only |
| `W-CONST-FIELD` | a constituent carries a field that the bridge would drop | design-only |
| `E-XML-IO-PREFIX-UNDECLARED` | an io prefix is not declared in the process aef:prefixes | `unresolved_reference` |
| `W-XML-IO-FIELD-UNKNOWN` | an io fieldRef is not in the project's field catalog | `unresolved_reference` |
| `W-XML-IO-MATCH-UNRESOLVED` | a match field has neither fieldRef nor path | `unresolved_reference` |
| `W-XML-GW-DEFAULT-NOT-OWN` | a gateway's default is not one of its own outgoing flows | `unresolved_reference` |
| `W-IO-INPUT` | a required input has no upstream node emitting a matching output | `missing_typed_input` |
| `W-XML-IO-INCOMPLETE` * | an object io lacks typeRef, source/target system or operation | `missing_typed_input` |
| `W-XML-IO-FIELD-ENTITY` * | an io field belongs to another object in the catalog | `missing_typed_input` |
| `E-XML-IO-EXPECT-CONTRADICTS` * | an aef:expect requires a value the attribute's own rule forbids | `missing_typed_input` |
| `E-XML-IO-MATCH-MISSING` * | an instance-changing operation names no match field (acts on every instance) | `missing_typed_input` |
| `W-XML-IO-MISSING` | steps carry no io at all, so nothing they read or write is recorded | design-only |
| `W-XML-IO-EXPECT-REDUNDANT` | an aef:expect repeats the catalog's own pattern | design-only |
| `W-GW-AMBIGUOUS` * | an exclusive gateway has more than one unconditioned outgoing edge (YAML) | `stale_position` |
| `W-XML-GW-AMBIGUOUS` * | an exclusive gateway has more than one unconditioned outgoing flow (XML) | `stale_position` |
| `W-XML-GW-BRANCH-UNCONDITIONED` * | a deciding gateway branch has no condition and is not the default | `stale_position` |
| `W-GW-OUTGOING` | an exclusive gateway has fewer than two outgoing edges (YAML) | design-only |
| `W-XML-GW-OUTGOING` | an exclusive gateway has fewer than two outgoing flows (XML) | design-only |
| `W-PGW-CONDITION` | a parallel fork's outgoing edge carries an ignored condition (YAML) | design-only |
| `W-XML-PGW-CONDITION` | a parallel fork's outgoing flow carries an ignored condition (XML) | design-only |
| `W-PGW-NOOP` | a parallel gateway neither forks nor joins (YAML) | design-only |
| `W-XML-PGW-NOOP` | a parallel gateway neither forks nor joins (XML) | design-only |
| `W-PGW-UNBALANCED` | a parallel fork has no matching join (YAML) | design-only |
| `W-XML-PGW-UNBALANCED` | a parallel fork has no matching join (XML) | design-only |
| `W-NO-START-EVENT` | no start event, so reachability was not assessed (YAML) | design-only |
| `W-XML-NO-START-EVENT` | no start event, so reachability was not assessed (XML) | design-only |
| `W-NO-END-EVENT` | no end event, so termination was not assessed (YAML) | design-only |
| `W-XML-NO-END-EVENT` | no end event, so termination was not assessed (XML) | design-only |
| `W-UNREACHABLE` | a node is not reachable from any start event (YAML) | design-only |
| `W-XML-UNREACHABLE` | a node is not reachable from any start event (XML) | design-only |
| `W-DEADEND` | no end event is reachable from a node (YAML) | design-only |
| `W-XML-DEADEND` | no end event is reachable from a node (XML) | design-only |
| `W-XML-DISCONNECTED` | the flow graph falls into disconnected parts | design-only |
| `W-XML-DOC-PREFIX` | a documentation line starts with no known prefix | design-only |
| `W-XML-DATA-UNLINKED` | a data object has no name or is linked to no step | design-only |
| `W-XML-POSITION-DI` | aef:position and the DI bounds disagree | design-only |
| `W-XML-LANE-GEOMETRY` | declared lane order disagrees with drawn geometry | design-only |
| `W-XML-LANE-CAPACITY` | a lane's declared height cannot contain its members | design-only |
| `I-XML-LANE-GEOMETRY-SKIP` | info: lane/geometry agreement not evaluated (nodes carry no position) | design-only |
| `I-XML-LANE-CAPACITY-SKIP` | info: lane capacity not evaluated (unknown node occupancy) | design-only |

## Inferred links (\*) — please check

1. **`unratified_procedure` ← kind codes** (`E-WORKFLOW-KIND`, `E-XML-WORKFLOW-KIND`,
   `W-XML-NO-WORKFLOWMETA`). The kind marker separates documentation maps from plans of
   actionable work. I read an invalid or missing kind as a map the runtime cannot accept as
   a procedure, so it is refused as never ratified. Ratification itself is not checkable at
   design time.
2. **`human_gate_skipped` ← `W-TYPE-LANE-MISMATCH`**. The node type says a human performs
   the step, the lane says otherwise, and the lane wins. I read this as an author's intended
   gate that the runtime would not hold, so an author who fixes it either moves the step to
   a human lane or retypes it. The other authority codes are stated links (authority-of-record,
   mapping-v1 §3) and are not marked.
3. **`capability_unsupported` ← unknown node type** (`E-NODE-TYPE`, `E-XML-NODE-TYPE`). An
   element no executor knows can never be performed. The nearest runtime route is "cannot do
   this, no silent substitution". `unresolved_reference` is the other candidate.
4. **`unresolved_reference` ← duplicate ids** (`E-UID-DUP`, `E-XML-ID-DUP`,
   `E-XML-UID-DUP`). A reference to a non-unique id resolves to two elements, which I treat
   as unresolved.
5. **`missing_typed_input` ← io codes** (`W-XML-IO-INCOMPLETE`, `W-XML-IO-FIELD-ENTITY`,
   `E-XML-IO-EXPECT-CONTRADICTS`, `E-XML-IO-MATCH-MISSING`). Each leaves a declared input
   untyped, sourceless, of the wrong object, unsatisfiable, or (match) without the key that
   picks the instance. `W-IO-INPUT` is the direct, stated link and is not marked.
   `W-XML-IO-MISSING` is mapped design-only: a step with no io declares no input, so there
   is nothing the runtime could find missing. It makes the check possible rather than
   preventing a refusal.
6. **`stale_position` ← ambiguous exclusive gateways** (`W-GW-AMBIGUOUS`,
   `W-XML-GW-AMBIGUOUS`, `W-XML-GW-BRANCH-UNCONDITIONED`). With more than one unconditioned
   branch, two proposals can each advance the same position along a different edge; the
   runtime admits one and refuses the other `stale_position` (§13 #19). This is the weakest
   link in the table.

## Not covered by the validator at all

`scope_mismatch`, `unmeasured_component_scope`, `duplicate_delivery`,
`direct_state_mutation`, `ambiguous_identity`, `task_hash_drift`,
`policy_or_capability_drift`, `bypass_input`, `cancellation_in_effect`,
`command_substitution`, `deadline_expired` and `privilege_exceeds_profile` are runtime-only.
For some of them a design-time check could exist if the map carried the data:
capability-profile and binding refs (`privilege_exceeds_profile`, `capability_unsupported`),
action/script contracts (`command_substitution`, `unresolved_reference` for actions), and
component scope (`unmeasured_component_scope`). That is a question for a later validator
version, not a defect in 0.43.0.

## How this is checked

`tests/unit/test_t5189_validator_refusal_mapping.py` parses `refusal.schema.json` and the
validator source, and asserts: every reason_code and every validator code appears exactly
once in the YAML and in this file's tables; Table A's "prevented by" and Table B's
"prevents" agree; and the sha256 of both sources matches the YAML. A new validator version
or a v3 enum makes the test fail until the mapping is redone.
