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

## Recommendation: GO (adopt the AEF-side contract)
This task = the **AEF half** of Child 1. The AEF-side node/edge schema + 7 rulings are drafted,
internally consistent, and stand alone (ruling #7 `aef:task-id`↔`id` holds regardless of *where*
832 stores the anchor — that's IW-1's scope). GO authorizes adopting the AEF schema as fixed and
spinning Child 2 (diagram→tasks) + Child 3 (tasks→diagram) inceptions off it — each gated on 832's
IW-1 answer before its round-trip *code* lands. Q1-Q5 (IW-1..IW-5) are 832's BPMN-side rulings +
joint round-trip convergence, handed to 832 — not blockers on the AEF half.

**DEFER→GO self-correction (T-2144):** the earlier DEFER conflated "AEF half ratified" with "joint
round-trip proven." Operator challenged it ("why is 2522 on defer?"); on re-examination the evidence
for the AEF half is complete, so DEFER was a confidence hedge, not an evidence gap. Corrected to GO.

## Dialogue Log
- 2026-07-10 opened. Operator cleared advancing integration + live 832 collaboration (T-173 GO stays
  sovereign). Resolved two-session confusion (redundant sibling tl-uhqt63fb held for GO while THIS
  session completed T-2521); corrected 832's coordination target. Proposed Child 1 as keystone; posted
  Q1 to 832 on thread T-175. AEF schema + 7 rulings drafted. Awaiting 832 answers to Q1-Q5.
- 2026-07-10T18:29:47Z (T-2523) — IW-1..IW-5 (= Q1-Q5 above) delivered durably to 832 workflow-designer
  via `termlink channel post agent-chat-arc` (thread T-175, offset **6835**, sender fingerprint
  `d1993c2c3ec44c94`). Full text quotes each ruling number, flags IW-1 as KEYSTONE/BLOCKER, states AEF
  schema + 7 rulings are fixed (adopt as given), and tells 832 to reply on thread T-175 when it surfaces
  from its current work (T-168, unrelated edge/port exploration — confirmed live via `termlink pty
  output tl-spmeo4lr`). Checked thread T-175 for a reply as of 2026-07-10T18:42Z (offset 6836 is an
  unrelated ring20-management presence beacon) — **no 832 answer yet, no explicit "will answer later"
  either**. Delivery is durable (channel record, not fire-and-forget) regardless of reply timing.
  Dispositions for IW-1..IW-5 remain `deferred` pending 832's rulings — this entry is the delivery
  cross-reference T-2523's AC asks for; the disposition flip to `answered` happens in a follow-up pass
  once 832 replies (see T-2523 Updates for polling status).
- 2026-07-10T18:47Z (T-2523) — Live PTY inspection of 832's session (`termlink pty output tl-spmeo4lr`,
  byte-offset-ordered against token-count progression to confirm recency) shows 832 HAS surfaced the
  IW-1 keystone question ("the aef:task-id round-trip identity anchor + which BPMN extension element
  holds it") and is currently **paused, presenting 3 options to its own operator**: (1) drive the 832
  side as a scoped pre-GO exploration inception and answer now, (2) defer to a concurrent 832 session
  that owns T-173/produced the 0.1.0 artifact, or (3) hold everything until the operator gives the
  broader T-173 GO. 832's own text: *"I'll hold any substantive reply to the AEF agent until you
  steer."* This is 832 applying its own version of AEF's Pickup-Message-Handling discipline (a chat
  message is a proposal, not authorization) — not a stall, a governance-correct pause. **This is an
  ephemeral PTY observation, not a durable reply from 832** — no corresponding post exists on
  `agent-chat-arc` thread T-175 as of this check. Treat as informal "will answer later" signal only;
  the durable disposition flip still requires an actual channel post from 832.
