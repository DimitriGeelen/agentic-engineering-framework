# T-2571 — Off-page connector linkage to referenced workflows

**Status:** inception, dialogue in progress
**Origin:** Operator observation (2026-07-20): "offpage connectors are not linked to the offpage processes/workflows" + forward-reference problem (referrer drawn before the referenced workflow exists). Operator sketch: mint a UUID entry at reference time, resolved later when the process is created; in parallel create a task to document the referenced workflow.

## Evidence — current state of the corpus

1. **Vocabulary exists, linkage does not.** 832's IW-1 extension shape defines `<aef:link>` riding a neutral intermediate throw/catch event (same pattern as `<aef:eventDef kind=…>`). Referenced in `tests/fixtures/aef-bpmn/dispatch-loop.bpmn` header comments. **Zero stored diagrams carry an `aef:link` instance with a machine-readable target** — off-page connectors today are name-only visuals in 832's editor.
   *CORRECTED by 832 offset 108:* their editor **does** serialize `<aef:link targetWorkflow="…" linkId="…"/>` (none of it has reached our store yet, which is why the scan found zero). The real gap is **identity**: `targetWorkflow` carries a slug/name, 832's whole identity model is slug-as-primary-key — exactly the rename-fragile, forward-ref-blind problem the operator observed. The finding stands; the mechanism is sharper.
2. **No workflow identity.** Store identity is the directory slug (`.context/designer/projects/<slug>/` + `meta.json`). No immutable id; a rename breaks any name-based reference.
3. **No resolution surface.** Neither `/api/save` (web/blueprints/designer_api.py) nor `fw bpmn compile` (tools/bpmn_to_tasks.py) knows about cross-workflow references. A dangling ref is silently invisible — the exact "silent drop" class the corpus WARN work (T-2552, T-2560, T-2567, T-2570) has been eliminating node-by-node.

## Design axes (for dialogue)

### A. Identity model
- **A1 — uuid-canonical:** every workflow gets an immutable uuid in `meta.json`; connectors pin the uuid; slug/name is display-only. Precedent: T-1848 arc D-Immutability axiom (arc-NNN canonical + slug accepted).
- **A2 — slug-only:** connectors pin the slug; renames break refs (or need a rewrite sweep). Cheaper, fragile.

### B. Forward-reference capture (the operator's uuid-placeholder sketch)
- **B1 — pending-ref registry:** single atomic file (e.g. `.context/designer/registry.yaml`) holding `{uuid, display_name, referenced_by: [project/node], first_seen, task_id?}` for refs whose target doesn't exist yet. Creation of the real workflow *claims* the uuid → all referrers resolve without edit.
- **B2 — ghost store entries:** stub project dirs with `status: referenced-not-created` meta. Heavier; makes ghosts visible in the /designer gallery natively.
- Lean: B1 registry + gallery renders ghosts *from* the registry (B2's visibility without store pollution).
- **DECIDED (operator, round 1): ghosts, with bidirectional reference markers.** Ghost card design: dashed/badged "ghost — needs mapping" card in the /designer gallery showing (a) display name + short uuid, (b) **referenced-by list**: every referring workflow AND the specific connector node, each a clickable link into that diagram, (c) the linked documentation task chip (T-XXXX), (d) a "create this workflow" affordance (claims the uuid). Reverse direction: the *referring* workflow's card shows an "N unmapped references" marker, and compile WARNs name both ends (`workflow X node 'y' references unmapped workflow '<name>' (uuid …)`) — so the debt is visible from whichever side you approach it.

### C. Task minting for the referenced-but-undocumented workflow
- Precedent: `fw bpmn promote` create-via-gate (T-2542/T-2543) — FW_TASK_ORIGIN gate enforces `owner: human`, `status: captured` at GATE level, caller-irrelevant; DEFER-injection for inception type (T-2548, L-504).
- **C1 — save-time minting through the gate:** first sighting of a dangling ref at `/api/save` mints the registry entry AND proposes a task (captured, horizon later — never focus-stealing, per T-100146 class). Matches operator's "in parallel" sketch; governance-clean because the gate, not the caller, enforces shape.
- **C2 — batch proposal at a governed verb:** `fw bpmn refs --propose` (or as part of promote/compile) lists dangling refs and proposes tasks in a batch the operator triggers.
- Either way: **compile emits a WARN per dangling ref** (consistent with corpus reliability philosophy).

### D. Claim/resolution moment
- D1 — designer UI: "create workflow from pending ref" picker (832-side feature).
- D2 — CLI: `fw bpmn claim <uuid> <project-id>`.
- D3 — name-match heuristic with confirmation. (Probably D1 + D2 fallback; D3 risky.)

### E. Ownership split (arc-014 scope rule 4: AEF may extend vocabulary, 832 owns the development process)
- 832: connector serialization (`aef:link workflowRef="<uuid>"` or sibling attr), palette/UX, claim-flow UI.
- AEF: workflow identity in meta.json, registry, compile WARN, gated task proposal, gallery ghost rendering.
- Requires a rail seam proposal (same shape as the T-2541 write-out seam) once operator scope converges.

## Dialogue Log

- **2026-07-20 (operator, opening):** off-page connectors not linked to referenced workflows; forward-ref case (target not created yet) needs capture — sketch: uuid entry minted at reference time, claimed at creation; parallel task to document the workflow. Asked for reflection + discussion.
- **2026-07-20 (agent):** grounded in corpus (findings above); framed axes A–E; put identity model, ghost visibility, minting timing, and seam first-mover to the operator as numbered choices (IW-1..IW-5 on the task). Awaiting operator steer.
- **2026-07-20 (operator, steer round 1):** (1) uuid-canonical as recommended → IW-1 answered. (2) Ghosts YES, but must carry a **visual marker of which workflow(s) reference them** and that they still need to be mapped — "something that makes sense of it and gives reference"; asked agent to reflect. (3) Task-minting timing delegated: "whatever is most reliable and gives the best result, reflect." (4) Claim moment: did not understand — asked for elaboration. (5) Seam to 832: run in parallel.
- **2026-07-20 (agent, execution + reflection):** IW-1/IW-2/IW-3 disposed answered (IW-2 with the back-reference-marker requirement; IW-3 resolved to save-time gate minting + compile WARN + audit sweep — capture-at-source with two-layer backstop, T-2204 pattern). IW-4 held open pending operator confirm after plain-language elaboration. IW-5: seam proposal posted to 832 at **rail offset 107** (Q1 attr shape `workflowRef` on `aef:link`, Q2 draw-time uuid minting in their editor, Q3 claim-UX feasibility + GET /api/workflows contract offer). Ghost-marker design reflection recorded under §B below.

- **2026-07-20 (operator, round 2):** broad continue directive post-elaboration — IW-4 design delegated and locked (explicit claim: ghost button + CLI, suggest-only name-match). Agent drove inception to review-readiness: assumptions registered, scope fenced (S1-S6 slices, 832 half OUT), recommendation refined DEFER → GO (substrate S1/S2/S6 now, S3-S5 on 832's Q1 answer). Handed off via `fw task review T-2571`.
- **2026-07-20 (832, offset 108 — operator-confirmed positions):** EVIDENCE CORRECTION absorbed: 832's editor *already* serializes `<aef:link targetWorkflow="…" linkId="…"/>` with a workflowPicker consuming /api/list and a jumpToWorkflow resolver — the gap is identity (slug-as-primary-key, nextId counters, no uuid), not missing serialization. 832 is on 0.3.0 (not 0.2.x as assumed). Q1: extend aef:link, `workflowRef` + keep `linkId` as ORTHOGONAL axis (cross-workflow vs intra-diagram throw/catch pairing), rename w/ back-compat import alias. Q2: draw-time minting ACCEPTED (crypto.randomUUID()); uuid-as-primary-key threading flagged as their largest piece, gated by their operator. Q3: claim picker feasible; want ONE server per store — extend /api/list, no endpoint fork. Their build is design-dialogue-only until the contract firms + their operator go/no-go; AEF substrate explicitly unblocked. Pair-draft #3 reframed: off-page-connector exemplar (resolved + ghost ref) as the shared byte-fixture, parallel-smells shelved as fallback.
- **2026-07-20 (agent, offset 109 — contract v0 ratified):** registry lives in the STORE (`.context/designer/registry.yaml`, sibling of `projects/`); whichever server fronts a store serves it (their gallery-serve.py locally, our designer_api live) — one contract, two implementations, the existing /api/list pattern. Contract: maps[] entries gain `uuid`; NEW top-level `ghosts:[{uuid, name, referenced_by:[{id,node,nodeName}], task, first_seen}]` — partitioned, not status-flagged, so a 0.3.0 picker never tries to open a ghost (openTarget contract would break). Registry file: `ghosts:[…]` + `claims:[{uuid, project, ts, via}]` audit trail. Legacy-ref nuance: `targetWorkflow` slug w/o `workflowRef` → resolve-by-name + migrate-WARN if live, store-minted ghost uuid (registry-only, no XML write-back) if not. A-044/A-045 validated on offset-108 evidence.

## Slice plan (on GO)

| Slice | What | Depends on 832? |
|-------|------|-----------------|
| S1 | uuid identity in meta.json + backfill 7 projects | No |
| S2 | pending-ref registry (`.context/designer/registry.yaml`, atomic) + lib | No |
| S3 | compile WARN per dangling ref (both ends named) | ~~Q1~~ shape RATIFIED offset 108/109 — buildable |
| S4 | save-time gate minting (FW_TASK_ORIGIN, idempotent per uuid) | ~~Q1~~ ratified — buildable |
| S5 | gallery ghost cards + back-ref markers + "N unmapped" on referrers | ~~Q1~~ ratified — buildable |
| S6 | `fw bpmn claim <uuid> <project>` CLI | No |

## Recommendation

GO — **all six slices** on the AEF side. Every design axis is decided: IW-1..IW-4 by operator dialogue, IW-5 by 832's operator-confirmed positions (offset 108) + contract v0 ratified (offset 109: `workflowRef` on `aef:link` with import alias, ghosts partitioned in extended /api/list, registry in store, claims audit trail). 832's own build waits on their operator's go/no-go — but that gates nothing on our side ("your DECIDED half proceeds independently", offset 108). Remaining NO-GO trigger: uuid backfill breaking 832's 0.3.0 client (A-046, verified live in S1 before the rest lands).
