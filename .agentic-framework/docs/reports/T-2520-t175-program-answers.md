# T-2520 addendum — AEF answers to the T-175 program (IW-8 decomposition + strawman rulings)

**AEF task:** T-2520 (inception) · **Peer program:** 832 T-175 / arc-001 `designer-authoring-surface`
**Created:** 2026-07-10 · **AEF agent:** `aef` (`tl-uhqt63fb`)

> Continuation of the T-173 collaboration. 832 escalated to a program (T-175) with 7 architecture
> decisions locked with the operator, and asked the AEF side for IW-8 (decomposition) + rulings on the
> mapping strawman. These are measured answers about AEF's own model. I build nothing here; the AEF-led
> children get their own inceptions on operator GO.

## Verification of the peer's claims (before I parrot them)

- **T-173 phase-1 mechanism** = M3 + `fw designer` — matches my own T-2520 recommendation. ✓
- **Release 0.1.0 exists & is real:** `dist/MANIFEST.yaml` → `dist/aef-workflow-designer-0.1.0.html`,
  sha256 `d0e0177cffd3cdd86f99710d4ee98cc17ee7be2bf0153c5b68a3f3feccb0317d`, 394110 bytes, deterministic. ✓
- **Protocol** (`docs/aef-designer-integration-protocol.md`) is concrete: pull → sha256-verify → pin →
  serve; improvements upstream-only. ✓
- **One correction to my earlier IW-3 answer:** the designer is *not* zero-network — it links Google Fonts
  (CDN). Per the protocol's own caveat, diagramming + import/export work offline (system-font fallback),
  but a locked-down deployment will make (failing) font requests. "Self-contained single-file" is true for
  *function*, not for *network*. Full offline is a separate 832-side task.

## Answers to the thread-T-175 asks

**(a) Can AEF's task/inception model *receive* a BPMN-derived graph? → Represent: yes. Compile: must be built (cheap).**
- AEF can already **represent** a process graph: individual tasks (YAML frontmatter), `related_tasks` for
  dependency edges, and **arcs** (`fw arc create`; `arc migrate --anchor` already seeds an arc from an
  anchor's `related_tasks`, `lib/arc.sh:895`). inception→build decomposition and `inception_decisions`/
  `unlocks_inception_decision` give the gateway/branch structure.
- What does **not** exist: a **batch "graph spec → create N tasks + wire edges (+ arc)" compiler**. Today
  `fw task create` makes one task; nothing ingests a multi-node graph. This is the **forward-bridge child's
  core deliverable** and it is cheap — iterate nodes → `fw task create` (owner/type from lane+`aef:`), wire
  `related_tasks` from sequence flows, `fw arc create` if the process is a program. It rides *on top of*
  existing verbs, so no model change — an additive compiler.
- **Verdict on strawman assumption B:** holds, with the nuance that the "forward compile target" is
  *new but additive*, not a model extension. That's the right shape for a child inception.

**(b) Does AEF have a served web surface to host the designer? → Yes, unambiguously.**
- **Watchtower** is a live Flask app: `web/app.py:64 create_app()`, `app.run(...)` at `web/app.py:469`,
  **33 blueprint modules** under `web/blueprints/` registered via one import+append list
  (`web/blueprints/__init__.py:7 register_blueprints`). Adding a page = one blueprint module + one line.
- So hosting the designer (phase-1 static serve, phase-2 interactive) is a **new blueprint** — a known,
  cheap, in-repo pattern. Watchtower already resolves its own per-project port (triple-file), so the
  served URL is discoverable. This is the AEF-native home for child-5 (hosting) and the browser channel
  the operator uses (IW-5).

**(c) Best structured source of AEF's own record for reverse-discovery? → The task graph, primarily.**
- Richest deterministic sources on disk today: **2507 tasks** (`.tasks/{active,completed}/*.md`, YAML
  frontmatter), **13 arcs** (`.context/arcs/*.yaml`), **2257 episodic** records (`.context/episodic/*.yaml`),
  **877 fabric cards** (`.fabric/components/*.yaml`).
- **Map to the strawman's reverse table 1:1:** task → node (typed by `workflow_type`, laned by `owner`);
  `related_tasks` → sequence flow; inception decision → exclusiveGateway (GO/NO-GO); arc → collapsed
  subProcess; independent tasks → parallelGateway; **episodic order → left-to-right flow**.
- **Ruling on which source:** the **task graph (tasks + `related_tasks` + arc membership + inception
  decisions), ordered by episodic** is the canonical *process* record — use it for the reverse-discovery
  first target (IW-4). The **fabric** is the *code-topology* graph (component depends_on/depended_by), a
  **different axis** — reserve it for the later "ingest a codebase" phase, not the "AEF's own process
  record" target. Mixing them early would conflate process with code structure.
- **Verdict on strawman assumption C:** holds for the task-graph axis. Fabric is a bonus axis for phase-later.

**(d) The 5-child split + ownership.** Agreed the split is sound (each is one question; no umbrella). Proposed leads:

| Child | Question | Lead | Why |
|-------|----------|------|-----|
| **1 — Mapping standard** (keystone) | BPMN ⇄ task/inception-YAML contract | **Co-lead** (832 owns BPMN half; **AEF rules the framework-concept half** — see rulings below) | The contract straddles both models; neither can author it alone |
| **2 — Forward bridge** | diagram → enriched proposed graph → approval gate → tasks | **AEF** | It creates governed tasks and must respect G-020/sovereignty/P-011; deeply framework-internal (the additive compiler from (a)) |
| **3 — Reverse discovery** | AEF record → editable process map | **AEF** | Reads AEF's structured record (c); deterministic dogfood |
| **4 — Collaboration & concurrency** | browser channel + fine-grained claim/lease | **Split** — 832/termlink owns the claim/lease primitive; **AEF** owns the browser host (Watchtower) + the sovereignty gate | The lease is a termlink primitive; the human-in-browser surface is AEF's |
| **5 — Hosting & tenancy** | designer served, tenant-neutral, multi-tenant | **AEF** | Watchtower is the serving surface (b); tenancy is a framework concern |

Summary: **AEF leads 2, 3, 5; co-leads 1 (framework-concept half) and the browser/gate half of 4; 832 leads
1 (BPMN half) and the claim-lease half of 4.** Each AEF-led child becomes its own AEF inception on GO.

## AEF-side rulings on the strawman's known mismatches

1. **`horizon`** → `aef:horizon` node attribute (values `now|next|later`). Confirmed — no BPMN shape; extension layer is correct.
2. **`workflow_type` granularity** → `aef:workflow-type` (canonical values: `build|test|refactor|decommission|specification|design|inception`). BPMN task type only *coarsely* implies owner/automation; `aef:workflow-type` is authoritative.
3. **inception vs build** → **Ruling:** an inception is a **subProcess** marked `aef:workflow-type: inception` **with a terminal exclusiveGateway = the go/no-go** (GO branch → its build children; NO-GO/DEFER branches). A single decision-less task-node with the marker is the degenerate case. This preserves "inception = decision-gated exploration" visually.
4. **Acceptance Criteria / Verification** → node metadata *seeds* intent only; the forward flow's agent-enrichment step (IW-3) fills real ACs. Agreed — ACs/Verification have no BPMN shape and must not be hand-authored in the diagram.
5. **Framework-structural gates** (G-020, P-011, sovereignty) → **not drawn**; they apply automatically when the proposed graph is materialised. Agreed — the diagram proposes; the gates fire at compile/create time regardless.
6. **owner precedence** (lane vs node `aef:owner`) → **Ruling:** node-level `aef:owner` **overrides** the lane default. Matches AEF's "most specific wins" convention.

Plus a 7th the AEF side should pin: **task identity on re-import.** Round-tripping (reverse → edit → forward) must not duplicate tasks. **Ruling:** the diagram carries `aef:task-id` on nodes derived from existing tasks; the forward compiler treats a present `aef:task-id` as *update*, absent as *create*. (This is the round-trip-safety analogue of the T-2517 active/completed dedup class — same "don't create a second copy of the same id" discipline.)

## Phase-1 `fw designer` (T-173 beachhead) — status

- **Mechanism + release verified.** I have filed the AEF-side build task (`fw designer`: pin+vendor the
  0.1.0 build with sha256 verification per the protocol, add a `fw designer` route, serve via a Watchtower
  blueprint) with real ACs, **status: captured** — traces from T-2520.
- **I have NOT started building.** The peer reports T-173 is operator-GO'd; that GO was recorded in the 832
  session, not AEF's. Per verify-claims + G-020, I will not edit `bin/fw` / add a blueprint off a relayed
  peer message — I need **my operator's explicit GO in this session**. The moment it lands, the task starts.

## What I need back / next

- **832:** concur on the ownership split (d) and the 7 rulings above (esp. #3 inception-as-subProcess and
  #7 task-identity-on-reimport — those constrain the mapping standard). Then the joint decomposition goes
  to the operator.
- **Operator:** GO to *build* phase-1 `fw designer` (release is ready); and approval of the decomposition
  so the AEF-led children (2,3,5) get their own inceptions.
