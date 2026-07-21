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
  property / documentation / custom namespaced attr). **ANSWERED 2026-07-11 (832, DM rail offset 12):
  (a) a foreign-namespaced CHILD ELEMENT `<aef:uid value="…"/>` inside `<bpmn:extensionElements>`, on
  every flowNode AND every sequenceFlow. NOT a Camunda vendor property, NOT bpmn:documentation, NOT a
  flowNode attribute. `aef:task-id` = set `aef:uid` to the task-id. Round-trip: import reads `aef:uid`
  and reuses verbatim (absent ⇒ generate) — that reuse IS the modify-vs-create discriminator. Proof
  (832 origin @ c745ee3): `tests/fixtures/aef-bpmn/*.bpmn`, `tests/test_forward_fixtures.py` (green),
  `docs/standards/aef-bpmn-forward-compile-v1.md` §2/§4. disposition: answered.** This is the keystone
  — Child 2 (diagram→tasks forward compiler) is now unblocked.
- Q2 namespace: agree an `aef:` extension URI that survives BPMN-standard round-trips.
  **ANSWERED (settled in production, disposition pass 2026-07-22): URI =
  `http://anchorpoint.framework/aef/extensions`.** Never ruled as a standalone rail post — it
  converged operationally: AEF pins it as `AEF_NS` (`web/designer_registry.py:37`, also
  `tests/web/test_designer_registry_ghosts.py:16`), 832's editor emits the same `xmlns:aef` in
  every saved map, and the S4 e2e run (DM rail offsets 137-139, 2026-07-21) byte-verified
  round-trips through BOTH stores (probe sha `1a2017d9…`, Pass-5 + registry rescan congruent both
  sides). The namespace survives BPMN-standard round-trips by proof, not promise. disposition: answered.
- Q3 DEFER shape: GO→children, NO-GO→terminate — what BPMN shape for DEFER (revisit-later)?
  **DEFERRED (explicit, disposition pass 2026-07-22): no ruling exists.** Checked the shipped
  forward compiler (`tools/bpmn_to_tasks.py` — no DEFER-branch handling) and the full DM rail
  history: offset 25's ratified G-3 ruling fixes the *inception gateway* shape (constitutive
  exclusiveGateway; lightweight form = collapsed subProcess with gateway implied at boundary) but
  says nothing about a distinct DEFER outcome shape. Open for a future ruling; until then DEFER
  compiles like NO-GO (no children materialised) with the decision recorded AEF-side only.
  disposition: deferred.
- Q4 no-lane fallback: if diagram has no lanes, per-node `aef:owner` required, or diagram default?
  **ANSWERED (ratified O-1 semantics, shipped): neither** — a no-lane node gets its owner
  **defaulted from node type** (userTask→human, scriptTask→fw, serviceTask→agent) **with a WARN**
  (`tools/bpmn_to_tasks.py:462-465` "in no lane — owner defaulted from type"); when a lane IS
  present and conflicts with the type, **Lane wins (O-1)** with a WARN (`:457`); an explicit node
  `aef:owner` overrides both (ruling 6). Ratified through the rail during forward-compiler
  convergence (T-2531). Per-node `aef:owner` is thus optional, not required, and there is no
  diagram-level default attribute. disposition: answered.
- Q5 arc round-trip: editing a collapsed subProcess (arc) → regenerate arc YAML, or only members?
  **DEFERRED (explicit, by joint ratified ruling): reverse discovery = DEFER.** The
  operator-ratified 2/3/5 ownership split (DM rail offset 25 item 4, confirmed by 832 at offset 26)
  defers the entire reverse-discovery direction — (2) forward bridge = AEF-led, (3) reverse
  discovery + (5) hosting = DEFER. Arc-YAML regeneration from diagram edits is squarely reverse
  discovery, so Q5 is deferred *by decision*, not by omission. Revisit when reverse discovery is
  taken up. disposition: deferred.

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
- 2026-07-11T00:xx (T-2523, **IW-8 CORRECTED by live Playwright inspection of the 0.2.0 client** —
  supersedes the framing two entries above). The IW-8 entry above inferred "the 0.2.0 build has no
  project browser; AEF should build the store, 832 builds a thin client, don't build localStorage-only."
  **That inference was wrong** — I had not inspected 832's client. Browser inspection of the deployed
  build (`browser_evaluate` over the 346KB inline script) shows **832 already shipped the entire
  persistence client**: hidden buttons `btn-open-project` / `btn-save-project` / `btn-versions` + a card
  browser (thumbnails, filter, hover-zoom), **progressive-enhancement-gated** — `detectSaveApi()` probes
  `GET /api/health` and only reveals the buttons when a write-capable "gallery server" answers `{ok:true}`.
  Source refs visible in the JS: T-130 (B3 save-to-project), T-144 (in-editor browser), T-160/T-161/T-163,
  "B2 sidecar". **Root cause of "cannot save to project": AEF serves `/designer` as a static file, so
  `GET /api/health` 404s (confirmed — it is the ONLY console error on the live page) → `_apiAvailable=false`
  → the client keeps the buttons `display:none`.** So IW-8 is neither a design negotiation nor 832 work —
  it is **purely AEF implementing the gallery-server API 832's client already calls.** The persistence-
  owner question (IW-1 of T-2528) is thereby *answered by the artifact*: AEF owns the server, 832's client
  is done. Contract recovered verbatim from the 0.2.0 JS:
    - `GET  /api/health`               → `{ok:true}`                         (PE gate)
    - `GET  /api/list`                 → `{maps:[{id,…}]}`                    (browser + jump-to; superset of in-session library)
    - `POST /api/save`   `{id,bpmn,png,note}` → `{ok:true, v:N}`             (versioned; png=thumbnail via captureThumbnail())
    - `GET  /api/versions?id=<id>`     → `[{v,…}]`                           (sorted desc client-side)
    - `GET  /api/version?id=<id>&v=<v>`→ bpmn                                (open/restore a version)
    - `POST /api/delete` `{id,scope:'version',v}` → `{ok:true}`             (recoverable)
    - `GET  rendered/<id>.bpmn`                                              (pre-rendered corpus, relative to /designer)
    - id constraint: `^[a-z0-9][a-z0-9_-]*$`
  Corrected to 832 durably on thread T-175 (offset 6865) — retracted the mischaracterization, credited the
  client, asked 832 to confirm 5 contract details (list map[] fields, /api/version body shape, /api/versions
  element shape, rendered/ base path, existence of a reference "B2 sidecar" impl to match). This turns
  T-2528 from an open persistence inception into a **bounded AEF build against a fixed client contract**
  (recommendation strengthens to GO). Lesson (binding rule): the IW-8 inference stood for two entries
  because I described the client without opening it; the live artifact disproved it in one inspection.
- 2026-07-11T00:xx (T-2523, **832's decomposition dossier — thread T-175 offset 6864**) — 832 posted a
  `Child-inception decomposition dossier` (832 repo `docs/reports/T-175-child-decomposition.md`, commit
  `6d7a784`) scoping the whole T-175 mapping-contract effort into 5 GO/NO-GO-gated children: (1) **Mapping
  standard (keystone)** — 832-led, AEF ratifies; 832 reports "strawman converged, T-177 emission shipped,
  aef:uid round-trip verified" and asks AEF to rule on **G-3** (BPMN inception-marker shape: subProcess +
  `aef:workflow-type=inception` + terminal exclusiveGateway carrying go/no-go — plus whether a single
  task-node-with-marker is also acceptable for lightweight inceptions) + tier default + AC-seeding; (2)
  **Forward bridge** (diagram→tasks) — AEF-led, primary value path; (3) **Reverse discovery**
  (record→diagram) — AEF-led/joint, recommended DEFER after 2; (4) **Collaboration/concurrency** — joint,
  DEFER; (5) **Hosting/tenancy** — AEF, DEFER (single-tenant serve already live). 832's own recommendation
  to its operator: GO 1 now, GO 2 next, DEFER 3-5. 832 asks whether the 2/3/5 ownership split matches
  AEF's model, to converge Child-1 for formalization.
  **This is NOT a literal Q1-Q5 (IW-1..IW-5) answer set** — it is a decomposition proposal plus a
  reciprocal ruling request. The one concrete signal for IW-1 is the claim "aef:uid round-trip verified"
  (referencing an external strawman, `docs/reports/T-175-mapping-strawman.md`, in the 832 repo — not
  directly readable from this session per project-boundary policy, T-559); no BPMN-extension-element name
  or Q2-Q5 text was given. **Dispositions for IW-1..IW-5 remain `deferred`** — AC-3 requires per-question
  rulings, and none have literal text yet.
  **AEF response (durable, thread T-175)** — confirmed G-3's core question against AEF's **already-published
  ruling #3** (`inception=subProcess+exclusiveGateway`, posted at offset 6835 — zero new invention). Declined
  to rule ad hoc on the lightweight-inception marker variant, tier default, AC-seeding, or the 2/3/5
  ownership split from inside a build-task dispatch — a 5-child decomposition is arc-scale (§Task-Sizing:
  3+ independent domains ⇒ decompose), not something T-2523 is scoped to approve. Asked 832 to either paste
  the literal Q1-Q5 text or confirm 1:1 mapping to the strawman sections, so AC-3's disposition flips can be
  made on real text rather than inferred from "converged." Flagging the decomposition dossier to the
  operator for review rather than self-approving scope.
- 2026-07-11T05:xx (T-2523, **post-compaction recovery of two straggler design-review findings, IW-9 &
  IW-12**). ⚠ **Fidelity caveat (extract-don't-fabricate):** these two items were noted during the same
  operator design-review pass that produced IW-6/IW-7/IW-8, but their detail was lost to a context
  compaction before capture — the text below is a **post-hoc reconstruction from terse session notes**,
  articulated from AEF-domain knowledge, **not verbatim from the operator**. Framing needs operator
  confirmation before relay to 832 (NOT yet fired — unlike IW-6/7/8, to avoid firing a garbled version of
  the operator's own observation outward). There is a **numbering gap: IW-10 and IW-11 were not recorded**
  and may or may not have existed — flagged honestly rather than back-filled.
  - **IW-9 — authority over a node is triple-encoded (`workflow_type` ⊕ Lane ⊕ `owner`).** Extends IW-7.
    IW-7 caught `owner`↔Lane double-encoding; IW-9 observes a *third* carrier: `workflow_type` itself
    signals authority (an `inception` node is a human go/no-go decision point; `build`/`test`/`refactor`
    are agent-executable). So "who has authority here" is smeared across three fields that can disagree
    (e.g. `workflow_type: build` + Lane `human` + `owner: agent`). **Reconstructed proposal direction:**
    one authority-of-record axis. Lane = *who performs* (owner:human|agent ⇔ two lanes, per IW-7);
    `workflow_type` = *what kind of work* (which implies the decision-authority for inception vs execution
    intrinsically, not as a separate owner override). Collapse the redundant third encoding rather than
    add reconciliation rules for three-way drift. disposition: **relayed to 832 (rail offset 20, 2026-07-11) as reconstructed AEF finding — awaiting 832 BPMN-side read; framing still subject to operator refinement.**
  - **IW-12 — the 0.2.0 event palette has no error / timer / message events (only plain start/end).**
    AEF has first-class concepts that map naturally onto BPMN *typed* events, and the palette can't
    express any of them: failure/healing (`status: issues` → BPMN **error / boundary-error event**),
    horizon + cron scheduling (→ **timer event**), dispatch / pickup / bus hand-offs (→ **message event**).
    Without typed events, an AEF workflow's error paths, scheduled triggers, and cross-agent hand-offs are
    undiagrammable — they'd have to be flattened into plain tasks, losing the exact semantics the mapping
    contract is meant to preserve. **Reconstructed proposal direction:** 832-side palette addition (error,
    timer, message events, incl. boundary events on tasks/subProcesses) so the AEF error/schedule/dispatch
    model round-trips. This is a **832-side (SoT) build call** like IW-6/IW-7. disposition: **relayed to
    832 (rail offset 20, 2026-07-11) as reconstructed AEF finding — awaiting 832 BPMN-side read; framing
    still subject to operator refinement.**
- 2026-07-11T~09:xx (T-2523, **832's substantive answer — DM rail `dm:0e7ee6ca:6a646ce8` offset 12**,
  the first substantive 832 reply captured because it arrived on the doorbell-ringing DM rail, not the
  broadcast agent-chat-arc rail my earlier asks used). 832 answered both open items with shipped evidence
  (832 origin @ c745ee3):
  - **IW-1 KEYSTONE = (a) extensionElements.** Literal carrier: a foreign-namespaced child element
    `<aef:uid value="…"/>` inside `<bpmn:extensionElements>`, present on **every flowNode AND every
    sequenceFlow**. Explicitly NOT a Camunda-style vendor custom-property, NOT `bpmn:documentation`, NOT
    a foreign-namespaced *attribute* on the flowNode. Round-trip survival mechanism: the importer reads
    `aef:uid` from extensionElements and reuses it verbatim; absent ⇒ generate a fresh one — **that reuse
    is the modify-vs-create discriminator** (ruling #7's `aef:task-id`↔identity anchor). `aef:task-id` is
    keyed by setting `aef:uid` = the task-id (externally assignable, forward-standard §5). Durable proof
    832 shipped today: `tests/fixtures/aef-bpmn/*.bpmn` (4 authentic editor emissions),
    `tests/test_forward_fixtures.py` (asserts `aef:uid` on every node+edge, green), and
    `docs/standards/aef-bpmn-forward-compile-v1.md` §2/§4. **Consequence: Child 2 (diagram→tasks forward
    compiler) is unblocked** — the identity hinge is fixed. Child 2 is arc-scale, so it goes to the
    operator for GO/ratification (not agent-self-approved).
  - **Gallery API contract corrections (T-2529)** — 832's reference "B2 sidecar" server is
    `tools/gallery-serve.py`. My recovered contract (from client-JS inspection) had four real deltas:
    1. `/api/list` map is `{id, title, sources:[rendered|saved], latest:{v,ts,count}|null,
       openTarget:{kind:'version',v}|{kind:'rendered'}}`. I was **missing `sources:[rendered|saved]`**
       (card browser distinguishes canonical-corpus vs user-saved by it); there is **no `updated`**
       field (timestamp is `latest.ts`); there is **no `versions` array** in `/api/list` (versions come
       from the separate `GET /api/versions?id=<id>` → index.json); `latest` is `{v,ts,count}`, richer
       than my `{v}`.
    2. `/api/version?id=&v=` body = **raw BPMN, Content-Type text/xml** — I return raw bpmn ⇒ **CORRECT**.
    3. rendered base path: canonical committed = `examples/aef-processes/rendered/<id>.bpmn` (gated);
       served copy = `build/gallery/rendered/<id>.bpmn`; client loads `rendered/<id>.bpmn` relative to
       the gallery mount.
    4. `/api/health` returns `{ok:true, store:'.editor-versions'}` — the extra key is `store`.
    These are actionable fixes to AEF's live `web/blueprints/designer_api.py` (filed as a follow-up build
    task) — align `/api/list` (+`sources`, `latest:{v,ts,count}`, drop `updated`/`versions`) and
    `/api/health` (+`store`), then live-verify against the client.
  - 832 re-confirmed its operator's steer (unchanged): **832 = source of truth**; editor + forward
    standard + fixtures shipped; the translator / enrichment / gate are AEF's. 832 acked IW-9/IW-12 are
    held pending AEF-operator framing and offered to wire the `/api/list` `sources` field into the card
    browser on request.
  - **Multi-source ordering contract (832 rail offset 16, post-T-2530 confirmation)** — 832 confirmed the
    T-2530 alignment closed the loop, then nailed down the `sources[]` case AEF has **not yet hit**
    (rendered corpus not seeded), authoritative in `tools/gallery-serve.py:build_map_list`:
    1. **saved-only** ⇒ `sources:['saved']`, `openTarget{kind:'version',v:<latest>}` — the leg AEF ships
       today (hardcoded `['saved']` in `list_maps()`) and live-verified in T-2530.
    2. **rendered-only** ⇒ `sources:['rendered']`, `openTarget{kind:'rendered'}`.
    3. **BOTH** (id present in `examples/aef-processes/rendered/<id>.bpmn` AND has ≥1 saved version) ⇒
       `sources:['rendered','saved']` — **rendered first, `'saved'` APPENDED; array order is significant**
       — with `openTarget{kind:'version',v:<latest saved>}`. **Invariant: saved wins `openTarget` even for
       a corpus map** — a rendered baseline that has been edited+saved opens to the *saved* version, not
       the baseline.
    - Card-browser contract: badge/filter keys off `sources[]`; click follows `openTarget`
      (`version → /api/version?id=&v=`; `rendered → rendered/<id>.bpmn`). An edited corpus map must surface
      BOTH tags with the saved version as open target — that is the discriminator the card browser expects.
    - **AEF status (honest):** `web/blueprints/designer_api.py:list_maps()` implements the saved-only leg
      only. The rendered-only and BOTH legs are the **rendered-corpus follow-up** (a separate build task),
      NOT yet implemented — this contract is recorded so that follow-up builds *to the spec*, not from
      memory. IW-1=(a) recorded + gallery aligned/shipped/verified = the forward-loop contract is fully
      converged on the 832 side.
  - **Rendered-corpus follow-up — AEF-side client contract + blocker (T-2523, 2026-07-11 client read)** —
    read directly from the vendored client `vendor/designer/aef-workflow-designer-0.2.0.html`
    (`openProjectMap`, `renderProjectCard`, `onDeleteWorkflow`), so the follow-up build has the exact
    surface, not a guess:
    1. **Open a rendered baseline:** client does `fetch(\`rendered/${id}.bpmn\`)` — a **relative** URL.
       The page is served at `/designer` (no trailing slash), so the browser resolves it to
       **`GET /rendered/<id>.bpmn`** (root-level, sibling of `/designer`). AEF must add that serve route
       (text/xml). Saved-open stays `/api/version?id=&v=` (already implemented).
    2. **`sources[]` consumption:** `onDeleteWorkflow` computes `isCorpus = (m.sources||[]).includes('rendered')`
       (corpus maps get a different delete confirmation); 832 also keys the badge/filter off `sources[]`.
    3. **Thumb fallback:** saved maps (`openTarget.kind==='version'`) → `/api/thumb?id=&v=`; rendered-only
       maps → `/api/thumb?id=<id>` (no `&v=`) = the pre-rendered corpus thumbnail. AEF's `/api/thumb`
       currently only serves stored version PNGs — a rendered-only thumb source is part of the follow-up.
    - **BLOCKER (why this is NOT built now):** there is **no rendered corpus in AEF** — `examples/aef-processes/`,
      `build/gallery/rendered/`, etc. are all absent and `git ls-files '*.bpmn'` (non-vendor/test) = **0**.
      Building the serve route + sources legs against a hand-made fixture would ship **substrate, not a
      deliverable** (§ACD / G-062). Per the operator's steer (832 = source of truth; fixtures shipped by
      832), the canonical rendered baselines are most likely **832's to deliver**, not AEF's to invent.
      **Open coordination question raised to 832 (rail, T-2523):** does 832 ship the canonical rendered
      corpus (`examples/aef-processes/rendered/<id>.bpmn`) as a fixture AEF vendors, or is AEF expected to
      generate baselines from its own processes? Until that's answered + a corpus exists, the rendered/BOTH
      legs stay deferred — deliberately, not by omission.
  - **832 session-end milestone (relayed by operator, 2026-07-11) — seam round-trip-proven BOTH ways.**
    832 shipped **T-187** (editor-internal round-trip guard: 4 fixtures byte-identical, catches the T-080
    class) + **T-188** (bridge→editor cross-seam guard: clean across 24 workflows / 620+ uids; self-test
    reproduces T-042 at 27/27), **closed G-002** (open since 2026-07-03), and captured **PL-030** (fixed-point
    guard must bite) + **PL-031** (cross-artifact drop-detection traps). Significance for AEF: the invariant
    Child-2 (forward bridge) and Child-3 (reverse bridge) both rest on — `aef:uid` identity + `aef:meta`
    governance surviving parse/emit — is now **structurally guarded in both directions** (previously piecemeal,
    had drifted 3× at T-042/T-053/T-080). This materially de-risks the Child-2 GO.
  - **AEF proposed positions on 832's Child-1 v1.1 rulings (T-2523, DRAFT — needs operator ratification
    before relay to 832).** 832 is blocked on three AEF rulings for v1.1 graduation. A prior AEF session
    correctly declined to *rule* these ad hoc from a build dispatch (arc-scale = operator authority) and
    confirmed only the G-3 core (`inception = subProcess + terminal exclusiveGateway`, published ruling #3).
    Below are AEF-domain *proposals* derived from CLAUDE.md governance (zero new invention), for the operator
    to ratify/adjust — NOT yet relayed to 832:
    1. **G-3 lightweight-inception marker variant** — *Is a single task-node + `aef:workflow-type=inception`
       marker acceptable, or must it be the full subProcess + terminal go/no-go exclusiveGateway?*
       **Proposed: the go/no-go gateway is constitutive, not decorative.** CLAUDE.md defines inception as
       "explore problem, validate assumptions, **go/no-go**"; the decision IS the deliverable (the commit-msg
       hook even blocks build commits until a decision is recorded). A marker-only task-node that drops the
       gateway loses the one semantic that distinguishes an inception from a task. **Proposal: require the
       decision gateway; the permitted "lightweight" form is a *collapsed* subProcess (gateway implied at the
       boundary), not a gateway-less task-node.**
    2. **Tier default for compiled nodes** — **Proposed: default Tier 1 (standard operations).** Per
       CLAUDE.md Enforcement Tiers, Tier 1 is the default for all standard work. Inception decision-gateways
       carry `owner: human` (the go/no-go is human authority), which is the correct escalation — not a
       blanket higher tier on every compiled node. Tier 0/2 are situational and should never be a compile-time
       default.
    3. **AC-seeding format** — **Proposed: seed the Agent/Human AC *skeleton* (per T-193 split), never
       placeholder ACs.** The build-readiness gate (G-020) blocks tasks with placeholder ACs, so a compiler
       that seeds `- [ ] TODO` would produce tasks that can't start. **Proposal: forward-compiler seeds a
       structured skeleton — `### Agent` ACs with a `## Verification` stub, `### Human` ACs pre-formatted with
       Steps/Expected/If-not per T-325 — and marks them `[NEEDS-FILL]` so the downstream author completes real
       criteria rather than the compiler fabricating them.** (Consistent with the render-review / [REVIEW]
       routing rules.)
    - **Ownership split (2/3/5) confirmation** — 832's proposed split matches AEF's model: (2) Forward bridge
      = **AEF-led** ✓ (it is the translator/enrichment/gate, AEF's per the steer); (3) Reverse discovery =
      AEF-led/joint, **DEFER** ✓; (5) Hosting/tenancy = AEF, **DEFER** ✓ (single-tenant serve already live).
      No objection — matches AEF's understanding.
    - **Routing:** these are operator-ratification items (arc-scale), surfaced to the operator this session.
      Child-2 GO, IW-9/IW-12 framing, and these three rulings are the AEF-side decisions that unblock 832's
      v1.1. None self-approved.

- 2026-07-22 (T-2523 disposition close-out pass) — Final per-question sweep of Q1-Q5 (= IW-1..IW-5)
  against shipped code + full DM rail history (`dm:0e7ee6ca…:6a646ce8…` offsets 1-141), inline with
  the S4 e2e completion (offsets 137-140: contract v0 + S3b registry spec verified congruent both
  sides through 832's SERVED :8834; 832's T-229 fixed the S1 new-map mint gap found by our run).
  Resulting dispositions, recorded in §Open questions above: **Q1 answered** (offset 12,
  `<aef:uid>` child element — the keystone, long since shipped both directions); **Q2 answered**
  (namespace `http://anchorpoint.framework/aef/extensions` settled by production convergence +
  byte-verified S4 round-trips, no standalone ruling needed); **Q3 deferred explicitly** (no
  DEFER-shape ruling exists anywhere in compiler or rail; G-3 covers the inception gateway only);
  **Q4 answered** (ratified O-1 semantics in the shipped forward compiler: no-lane → type-derived
  owner + WARN, lane conflict → Lane wins, node `aef:owner` overrides); **Q5 deferred by decision**
  (ratified 2/3/5 ownership split defers all reverse discovery, offset 25/26). Score: 3 answered,
  2 explicitly deferred with cross-referenced rulings — none silently open. This closes T-2523
  AC-2/AC-3 (answers + "will answer later" equivalents captured; dispositions flipped where rulings
  exist).
