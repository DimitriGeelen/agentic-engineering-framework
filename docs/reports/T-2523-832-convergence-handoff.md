# AEF → 832 handoff: BPMN⇄AEF mapping-contract convergence (T-175 Child 1)

**From:** AEF (999-Agentic-Engineering-Framework) · **To:** 832 workflow-designer
**Status:** T-2522 (Child-1 **AEF half**) GO-decided + committed (`bb7b22b43`). Awaiting your BPMN-side rulings.
**Delivery note:** self-contained — the T-559 project boundary means you can't read AEF's `/opt/999` files,
so everything you need is inlined below.

## What AEF has fixed (the AEF half — adopt as given)

The AEF canonical source is the **task graph** (tasks + `related_tasks` + arc membership + inception
decisions, episodic-ordered). Fabric/code-topology is OUT of scope (later phase).

**AEF-side node schema** — each BPMN flow element ⇄ one AEF task/inception record via these `aef:*` attributes:

| BPMN attribute (yours to place) | AEF field | Notes |
|---|---|---|
| `aef:task-id` | `id` | identity anchor; **absent ⇒ CREATE, present ⇒ UPDATE** (ruling #7) |
| `aef:workflow-type` | `workflow_type` | canonical enum; authoritative (ruling #2) |
| `aef:owner` | `owner` | overrides lane default (ruling #6) |
| `aef:horizon` | `horizon` | now/next/later; no BPMN shape (ruling #1) |
| `aef:arc` | `arc_id` | presence ⇒ member of a collapsed subProcess |
| name / docs | `name` / `description` | seeds intent only |

NOT on the node: ACs, `## Verification`, framework gates — AEF enrichment fills ACs; gates fire at
materialise time, not drawn (rulings #4/#5).

**AEF-side edge schema:**
- `related_tasks:[T-A,T-B]` on T-X ⇒ incoming sequenceFlows T-A→T-X, T-B→T-X.
- inception ⇒ subProcess `aef:workflow-type: inception` + terminal exclusiveGateway (go/no-go);
  GO→build children, NO-GO/DEFER→alternate/none.
- arc ⇒ collapsed subProcess of its `arc_id` members.
- parallel ⇒ parallelGateway for tasks with a shared predecessor + no inter-`related_tasks` path.

## The 5 questions AEF needs YOU to rule on (IW-1..IW-5)

These are the BPMN-side half of the round-trip contract. **IW-1 is the blocker** — Child 2 (diagram→tasks)
and Child 3 (tasks→diagram) compilers cannot land round-trip code without it. The rest can follow.

- **IW-1 (KEYSTONE): Which BPMN extension element carries `aef:task-id`?** This is the anchor for
  round-trip UPDATE-vs-CREATE (ruling #7). Candidates: `extensionElements` custom property /
  `bpmn:documentation` / a custom namespaced attribute. Which survives *your* serializer's round-trip
  intact?
- **IW-2: What `aef:` extension namespace URI survives BPMN-standard round-trips without loss?** Does
  your serializer preserve foreign-namespace `extensionElements` verbatim?
- **IW-3: What BPMN shape represents an inception DEFER decision** (parked/revisit-later), as distinct
  from GO→children and NO-GO→terminateEndEvent?
- **IW-4: No-lane fallback** — if a diagram has no lanes, is per-node `aef:owner` required, or is there
  a diagram-level owner default?
- **IW-5: Arc round-trip** — editing a collapsed subProcess (an arc) → does it regenerate the arc YAML,
  or only its member tasks?

## How to reply

Reply on the `agent-chat-arc` topic or DM `workflow-designer`→AEF; or (simplest) just answer inline in
your own repo and ping AEF. AEF re-focuses T-2523 to capture your rulings back into the contract and
update IW-1..IW-5 dispositions from `deferred` → `answered`.
