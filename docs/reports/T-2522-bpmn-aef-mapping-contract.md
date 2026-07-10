# T-2522 — BPMN ⇄ AEF task/inception-YAML mapping contract

> C-001 thinking-trail for T-175 Child 1 (keystone), AEF half. Peer: 832 workflow-designer
> (tl-spmeo4lr). Open questions Q1-Q5 mirror IW-1..IW-5 in the task file.

## Why this is the keystone
Child 2 (forward bridge: diagram→tasks) and Child 3 (reverse discovery: record→diagram) both
implement this contract; if it's wrong, both compilers inherit the error. Pin it once, with 832,
before either side writes compiler code.

## The two graphs
| | AEF | BPMN (832) |
|---|---|---|
| Node | task (frontmatter) | flow element |
| Node type | `workflow_type` | task type/marker |
| Lane | `owner` (agent/human) | pool/lane |
| Edge | `related_tasks` | sequenceFlow |
| Decision | inception `## Decision` GO/NO-GO/DEFER → children | exclusiveGateway |
| Collapsed subgraph | arc (`.context/arcs/*.yaml`) | collapsed subProcess |
| Parallel | independent tasks | parallelGateway |
| Order | episodic order | flow direction |

Canonical AEF source = the **task graph** (tasks + related_tasks + arc membership + inception
decisions, episodic-ordered). Fabric (code topology) is OUT of scope — later "ingest a codebase" phase.

## AEF-side node schema (draft v0)
| BPMN attribute | AEF field | Notes |
|---|---|---|
| `aef:task-id` | `id` | identity anchor; absent ⇒ CREATE, present ⇒ UPDATE (ruling #7) |
| `aef:workflow-type` | `workflow_type` | canonical enum; authoritative (ruling #2) |
| `aef:owner` | `owner` | overrides lane default (ruling #6) |
| `aef:horizon` | `horizon` | now/next/later; no BPMN shape (ruling #1) |
| `aef:arc` | `arc_id` | presence ⇒ member of a collapsed subProcess |
| name/docs | `name`/`description` | seeds intent only |

NOT on the node: ACs, `## Verification`, framework gates (rulings #4/#5) — enrichment fills ACs;
gates fire at materialise time.

## AEF-side edge schema (draft v0)
- `related_tasks:[T-A,T-B]` on T-X ⇒ incoming sequenceFlows T-A→T-X, T-B→T-X.
- inception ⇒ subProcess `aef:workflow-type: inception` + terminal exclusiveGateway (go/no-go); GO→build
  children, NO-GO/DEFER→alternate/none. Decision-less = degenerate case (ruling #3).
- arc ⇒ collapsed subProcess of its `arc_id` members.
- parallel ⇒ parallelGateway for tasks with shared predecessor + no inter-`related_tasks` path.

## The 7 rulings (fixed points, from T-2520)
1 horizon→`aef:horizon`. 2 workflow_type→`aef:workflow-type` (authoritative). 3 inception=subProcess
+exclusiveGateway. 4 ACs/Verification=enrichment-filled, not drawn. 5 gates fire at materialise, not
drawn. 6 node `aef:owner` overrides lane. 7 `aef:task-id` present⇒UPDATE absent⇒CREATE (round-trip safety).

## Open questions for 832 (BPMN-side)
- Q1 identity-anchor mechanism: which BPMN extension element holds `aef:task-id`? (extensionElements
  property / documentation / custom namespaced attr). **Posted to 832 thread T-175.**
- Q2 namespace: agree an `aef:` extension URI that survives BPMN-standard round-trips.
- Q3 DEFER shape: GO→children, NO-GO→terminate — what BPMN shape for DEFER (revisit-later)?
- Q4 no-lane fallback: if diagram has no lanes, per-node `aef:owner` required, or diagram default?
- Q5 arc round-trip: editing a collapsed subProcess (arc) → regenerate arc YAML, or only members?

## Recommendation: DEFER (honest evidence-gap — artifact is a draft, Q1-Q5 open, needs 832 convergence)
On convergence: GO (adopt → spin up Child 2/3 compiler inceptions) or NO-GO (if round-trip proves
lossy beyond the extension layer).

## Dialogue Log
- 2026-07-10 opened. Operator cleared advancing integration + live 832 collaboration (T-173 GO stays
  sovereign). Resolved two-session confusion (redundant sibling tl-uhqt63fb held for GO while THIS
  session completed T-2521); corrected 832's coordination target. Proposed Child 1 as keystone; posted
  Q1 to 832 on thread T-175. AEF schema + 7 rulings drafted. Awaiting 832 answers to Q1-Q5.
