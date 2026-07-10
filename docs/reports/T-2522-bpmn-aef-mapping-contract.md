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
- 2026-07-10T19:xx (T-2523, post-compact resume) — Re-checked the durable thread T-175 (offset 6835)
  via `termlink_channel_thread`: still only AEF's root post, zero 832 reply. Re-read 832's live PTY
  (session `tl-spmeo4lr`, still churning at ~189K tokens — 832 agent IS alive, not just the heartbeat
  wrapper): 832 has explicitly parsed AEF's IW-1..IW-5 ("their identity-anchor question", "AEF on
  T-175") and is holding its substantive reply behind a 3-way operator decision — (1) drive the 832
  BPMN side as a scoped pre-GO exploration inception, (2) let the concurrent T-173-owning 832 session
  (produced 0.1.0 + commit a1f8d56 + T-174) be the counterpart, (3) defer until the broader T-173 GO.
  832 offered to send AEF a "brief holding ack." **AEF response** — posted a durable async-ack to
  thread T-175 (**offset 6844**, depth 1 under 6835): affirmed 832's governance-pause is correct, stated
  AEF is NOT blocked-waiting (AEF half is GO+committed, async watch mode, no clock), declined the
  holding ack, and flagged IW-1 as the *sole* hard blocker for Child 2/3 so a minimal pre-GO scope can
  unblock the critical path. Convergence (T-2523 capture AC) remains genuinely blocked on 832's
  operator's sovereign 1/2/3 steer — not forceable from the AEF side; dispositions stay `deferred`.
- 2026-07-10T19:xx (integration surface, live-verify) — Independently of the convergence block, the
  `/designer` integration surface that T-2521 (vendor/serve) + T-2524 (pin-drift guard) exist to protect
  was verified LIVE end-to-end (not HTTP-200-as-proxy): `GET http://192.168.10.107:3001/designer` → 200,
  served bytes **sha256 `d0e0177c…` byte-identical to the pinned vendored 0.1.0 build** (served==vendored
  ==pin, 394110 bytes), genuine content (`<title>AEF Workflow Designer — investigate.bpmn</title>`, 343
  designer markers, zero real error surfaces — the one "not found" hit is an in-app JS alert string). The
  vendor→serve→pin-guard chain works on the live user surface.
- 2026-07-10T22:xx (T-2523, operator design review of the 0.2.0 node-extension fields) — Operator
  inspected the live `/designer` AEF-extension panel on the deployed 0.2.0 build and raised two
  field-design defects. Both verified correct; both are **832-side (SoT) design decisions**, so they
  become new convergence items on top of IW-1..IW-5. AEF vendors the released build and does not edit it —
  the fix routes upstream to 832.
  - **IW-6 — `horizon` does not belong on a design-time node (category error).** `horizon`
    (now/next/later) is transient, per-instance scheduling state; it is answered at instantiation
    (`fw work-on` / task-create), relative to a live session's *this moment*. A BPMN diagram is a reusable
    template — the same node is `now` this run, `later` the next. A design-time `horizon` field is
    therefore either dead metadata the runtime must ignore, or a stale default every instantiation
    silently inherits while looking authoritative. Contrast: `workflow_type / owner / tier / endpoint /
    contextReads / artifactsWrites` ARE properties of the work and true every run — they belong on the
    node. `horizon` is a property of *when you schedule it*. **Recommendation: remove `horizon` from the
    node extension; set it at instantiation.** disposition: deferred (832 owns the build).
  - **IW-7 — node-level `owner` double-encodes ownership already carried by the BPMN Lane.** BPMN's native
    "who performs this" is the Lane (swimlane = role/participant); the panel's Lane already reads `human`.
    A separate node-level `owner` field that "overrides lane" encodes the same fact twice → two sources of
    truth that drift. Concrete failure: Lane=`human`, Owner=`agent` — the override wins but the diagram
    now *lies* (node sits in the human swimlane while agent-owned; any reader is misled). **Recommendation:
    Lane is the source of truth for owner (`owner: human|agent` ⇔ two lanes); node-level owner is an
    exception escape-hatch only, shown with a divergence warning when it disagrees with the lane — not a
    co-equal field inviting routine double-entry.** disposition: deferred (832 owns the build).
  - Both findings surfaced from the operator visually reviewing the fields the T-177 `aef:meta` mapping
    emits — i.e. the mapping contract shipped `horizon` and `owner` onto nodes without first resolving
    whether they are design-time or instance-time (horizon) and whether they collide with a native BPMN
    construct (owner↔lane). Relay to 832 on thread T-175 pending (outward-facing; not fired blind).
  - **IW-8 — no project/workflow browser, cannot save to a project (persistence + navigation subsystem
    missing).** Operator: the 0.2.0 build can diagram + import/export a single file, but there is no way
    to *browse* existing workflows or *save into a project/library* — the editor is stateless per load.
    This is a materially larger item than IW-6/IW-7 (a field nit vs a whole subsystem) and it is
    **cross-boundary**, not purely 832-side: `/designer` is currently a *static single-file serve*
    (`web/blueprints/designer.py` → `_pin()` → `vpath.read_text()`), so **AEF exposes no save/list
    endpoint whatsoever**. Before either side builds, a design decision is required on WHERE workflows
    persist and who owns that store:
      - (a) **AEF backend** — AEF adds `GET /designer/projects` (list) + `POST /designer/projects/<id>`
        (save) routes backed by a `.context/` or repo-tracked workflow store; the 832 build wires its
        browse/open/save UI to those endpoints. Keeps AEF as the system-of-record for workflows-as-repo-
        artifacts (fits "nothing gets done without a task" — a saved workflow is a durable artifact).
      - (b) **832 build local storage** — the single-file editor persists to browser localStorage /
        File System Access API. Zero AEF backend, but workflows are trapped per-browser, not repo-tracked,
        not shareable — violates Portability + the repo-as-SoT model.
      - (c) **file-round-trip only** (status quo) — no browser; save == export a `.bpmn` file the operator
        manually re-imports. Honest but poor UX; the operator's report is that this is insufficient.
    Recommendation direction: **(a)** — workflows are first-class repo artifacts, so persistence belongs
    on the AEF side with 832's editor as the thin client. That makes IW-8 an **AEF-side inception**
    (new subsystem: workflow store + list/save routes + designer client wiring), distinct from the
    832-side build-nits IW-6/IW-7. Scope with §Task-Sizing (project browser + save + store = 3 deliverables
    → decompose after the go/no-go). disposition: deferred (needs the persistence-owner decision first).
