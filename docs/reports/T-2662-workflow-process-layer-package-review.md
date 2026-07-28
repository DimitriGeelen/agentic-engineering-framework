# T-2662: Workflow Process-Layer Package v1 (2026-07-02) — review vs delivered state

**Reviewed:** `aef-workflow-process-layer-package-v1-2026-07-02.zip` +
`INGESTION-workflow-process-layer-2026-07-02.md` +
`INSTRUCTIONS-workflow-process-layer-2026-07-02.md` (r3), supplied by operator from
`~/Downloads` on 2026-07-28.

**Question asked:** the package was believed ingested with an arc + tasks created
(including tasks for the AEF agent). Check, review against it, report progress and gaps.

---

## 1. Ingestion trace — the package was NEVER formally ingested into the AEF repo

Searched (2026-07-28):

- No `DISCOVERY-workflow-process-layer-*.md` anywhere in the repo (Step 0 deliverable).
- No `NOTE-schema-friction-inception-*.md`, no `inception-lifecycle.workflow.yaml`
  (Step 0.5 deliverables). No `workflows/` directory at repo root (SD-5).
- No arc in `.context/arcs/` named or describing the process layer; no task in
  `.tasks/{active,completed}/` referencing the package name, "Q1–Q10", "SD-1..15",
  "Lock 1..6", or "Workflow Fabric". (The only greps that matched were incidental
  uses of the words "process layer" in T-2428 and T-962, unrelated.)
- No mention on the 832 DM rail (searched "process layer", "Lock 1", "SD-", "package"
  across the full channel history).
- arc-014's grill artifact (`docs/reports/T-2553-designer-corpus-inception.md`,
  2026-07-19) does not cite the package.

**Where it likely DID land: 832's side.** The package's prototype
(`prototype/aef-workflow-designer.html`, single-file, v2 schema, BPMN round-trip,
`roundtrip.js` test) is recognisably the seed/lineage of 832's product (single-file
bundle, now 0.7.x; round-trip tests; aef:* BPMN vocabulary). Rail offset 23 shows
832's canonical corpus is `examples/aef-processes/<id>.workflow.yaml` → rendered
`.bpmn` — exactly the package's §2.1 file convention (`<name>.workflow.yaml`, YAML
canonical, BPMN derived). The T-559 project boundary blocks reading `/opt/832`
directly, so a rail question was posted to 832 (T-2662 AC-2) asking which of their
arc/tasks trace to the package. Their answer completes this section.

**Net:** the "arc with tasks including for the AEF agent" the operator remembers is
not in this repo. The AEF-side work that *covers the same ground* — arc-014
(designer-corpus) and its constituent tasks — was created 2026-07-19 via an
independent operator grill, without the package as input. The two efforts converged
on much of the same territory by different routes, and diverged on the architecture
core (see §3).

## 2. Progress map — package spec item → delivered analogue

| Package item | Status | Delivered analogue (evidence) |
|---|---|---|
| **Lock 2** — BPMN interchange, uid-preserving round-trip (V3) | **Delivered** | `fw bpmn compile` + gated promote (T-2531, T-2539, T-2542/T-2543); `aef:uid` identity preserved; live editor round-trip verified via Playwright (T-2644); joint bats `bpmn_promote_e2e.bats` ratified both sides (rail offsets 80/81). |
| **Lock 5** — dogfood corpus of 5 core processes (V4) | **Delivered, different set** | 5 real AEF maps live in `.context/designer/projects/`: aef-task-lifecycle (v4), aef-inception-flow (v4), aef-dispatch-loop (v3), aef-session-lifecycle (v3), aef-audit-cron (v3). Selection was telemetry-based per explicit operator instruction (T-2553 grill Q7) — NOT the package's regression-history catalog. Overlap with the package's catalog: inception only. |
| **Lock 3** — governance lifecycle, ratified-immutability, agent gates | **Partial** | Promote is the production-release gate: `FW_TASK_ORIGIN` gate, owner:human + captured-at-gate (T-2542/T-2543); frozen-v1 mapping standard under 832-operator sign-off (832 T-189/T-190); draft tier `draft-` prefix = cheap iteration, promotion = release (T-2623); version bump per promote ≈ SD-6 in spirit. No formal ratify/deprecate verbs or status frontmatter on maps. |
| **V6** — judge separation (validator catches what the permissive editor allows) | **Delivered, analogue** | `fw corpus lint` (2-finding steady baseline) + `fw corpus prove` (derive-in-memory identity proof, T-2608) + 832's strict-parse (T-2614). |
| **V9** — drift detection | **Exceeded** | Conformance-rail program (T-2621, T-2652 GO + slices T-2654/T-2658/T-2659): maps audited daily against the ENFORCED machine in code — transition-table + vocabulary-set primitives, `tools/conformance-registry.yaml`, 4 of 5 maps railed (3 green, 1 honestly red). The package only specced component-ref drift reports; the rails check semantic map-vs-code parity. |
| **V5** — composition (handoff pairs, callActivity) | **Partial** | Cross-map handoff jumps live in corpus v2 (T-2586, T-2613); drill-down settled as generalized sub-workflows via collapsed subProcess + cross-map jumps (T-2620 round 3). No typed input/output contract validation between workflows. |
| **SD-11** — human touchpoints on userTask | **Partial** | Lane→owner semantics with O-1 Lane-wins and O-3 Human-authority veto (T-2531, T-2540); decisionOwner serialization 832-side. No humanTouchpoint block (surface/contextBundle/timeout), no Watchtower routing from map nodes. |
| **Live observability** (not in the package!) | **Delivered beyond spec** | Overlay seam: live PROCESS-level state badges projected onto map uids (T-2630/T-2632/T-2634) — answers T-2619's "troubleshoot" gap with map-as-live-mirror. The package's enforcement ladder had no live-mirror rung at all. |
| **Step 0.5** — inception-lifecycle first article | **Analogue only** | `aef-inception-flow` map exists (v4, conformance-railed green against `lib/inception.sh`). But the paper exercise as specified (draft against v3 YAML schema, determinism status per node, friction note) never ran. |

## 3. Divergence by design — deliberate inversions (not gaps)

1. **Canonical representation inverted.** Package: YAML canonical, BPMN derived, the
   designer is a view surface. Delivered (AEF side): single stored representation in
   the designer store with spec derivation in-memory (T-2608, IW-1 dissolved) —
   BPMN-stored, `fw corpus derive/generate/canon/diff/prove` around it. 832's side
   retains `.workflow.yaml`-canonical for their examples corpus. Settled decision,
   not drift.
2. **Enforcement direction inverted.** Package ladder: advisory → guided → strict —
   the map progressively constrains execution (`fw workflow advance`, instance
   files). Delivered: reverse conformance — CODE is the enforced machine, the MAP
   must match it, audited daily (T-2652 program). T-2619's keystone question ("which
   direction does authority flow?") was answered mirror+rails, not map-as-spec.
3. **Dogfood selection basis.** Package: worst-regression-history processes
   (exception-handling, task-creation, tier0-escalation, knowledge-leveling).
   Operator instructed telemetry-based selection instead (T-2553 grill Q7).
4. **Two-agent split.** The package addressed a single framework agent. Reality is a
   pair: 832 owns the designer product + schema vocabulary (rail ratification loop,
   frozen-v1 standard), AEF owns corpus content + conformance + serving. The
   additive-only, fixture-pinned rail protocol substitutes for several of the
   package's single-repo governance mechanisms.

## 4. Gaps — package items with NO delivered analogue

1. **SD-1..SD-15 register never disposed.** Every disposition remains a design-agent
   proposal. Some are moot or settled de facto (SD-5 `workflows/` location — moot;
   SD-6 immutability — promote-versioning in spirit; SD-9 callActivity — subProcess
   drill-down settled by T-2620). Genuinely open and worth an operator ruling:
   **SD-1** (is Process the third foundational core concept? never confirmed — the
   delivered architecture arguably answers "yes, but as mirror+rails, not executable
   spec"), **SD-3/SD-10** (task↔workflow binding — no `workflow:` key in task
   frontmatter exists), **SD-13** (Component Fabric linkage — zero `components:`
   refs on any map), **SD-14** (pseudocode lens).
2. **Step 0 discovery (Q1–Q10) never ran.** Q5 (fabric ID stability) and Q10
   (instance-state cage / autonomy-integrity) were flagged highest-consequence and
   remain unanswered — Q10 becomes load-bearing the moment anything guided-mode-like
   is attempted.
3. **P1 lenses: nothing.** No functional/logical/technical per-audience rendering,
   no pseudocode lens, no business-view filtering (V1, V2, V8 unmeasured/unmet). The
   overlay is a live-state lens, not an audience lens.
4. **Lock 6 guided mode: nothing.** No `fw workflow bind/advance`, no instance
   tracking, no procedure-level human-gate protection (V7 unmet). This is the
   package's central structural promise — P3, "workflows enforce at the procedure
   level what verb gates enforce at the action level" — and it is wholly unbuilt.
   T-2620's trigger-model dialogue (observation layer firing actionable triggers)
   touches the territory but enforces nothing.
5. **Lock 4 Workflow Fabric: nothing.** No workflow-entity registry, qualified
   addressing, or role-level queries ("the Sovereign's workload surface across
   workflows"). Corpus handoffs exist as map content, not as a queryable index.
6. **The package's four worst-regression processes remain unmapped**
   (exception-handling, task-creation, tier0-escalation, knowledge-leveling). P4's
   falsifiable claim — explicit workflows reduce regression on exactly these — was
   never tested. arc-014's telemetry selection was a defensible operator call, but
   it means the package's core experiment never ran.
7. **P2 consumption is weak** (delivered-but-unused): T-2619's critical review found
   agents never read the maps during work; CLAUDE.md remains the sole workflow
   authority; corpus is write-mostly. T-2622 (agent retrieval seam,
   `fw corpus explain`) is the active counter-measure — in progress.

## 5. Recommendation

The delivered state is not a failed ingestion — it is a sibling architecture that
reached several of the package's own goals first (interchange, dogfood corpus, drift
detection) and consciously inverted its two core axes (canonical format, enforcement
direction). Actionable residue:

1. **Operator: dispose SD-1 explicitly** (one sentence suffices) — "Process layer =
   corpus + conformance rails + overlay, mirror-direction" ratifies the delivered
   architecture and formally retires the package's YAML-canonical/guided-mode shape;
   OR keep guided mode alive as a named future arc. Everything else in the register
   inherits from this call.
2. **If P3/P4 still matter:** the cheapest honest test is mapping ONE
   worst-regression process (tier0-escalation — small, pure governance, human
   gateways throughout) and railing it — that tests the package's foundational claim
   inside the delivered architecture without building Lock 6.
3. **832's answer to the rail question** (posted this session) determines whether an
   832-side arc already tracks the package's remaining scope — do not duplicate it
   here until that answer lands.

Related: T-2619 (designer authority model — the de-facto retrospective on this
territory), T-2553 (arc-014 grill), T-2652 (conformance-rail program).

## 6. Gap tasks filed (2026-07-28, operator-directed, all `arc_id: designer-corpus`)

| Task | Type | Horizon | Gap covered |
|------|------|---------|-------------|
| T-2663 | inception (rec **GO**) | now | SD-1..15 register disposition — ratify mirror+rails as the Process layer |
| T-2664 | build | next | tier0-escalation map + rail — the P4 falsifiability test |
| T-2665 | build | later | exception-handling map + rail (gated on T-2664 outcome) |
| T-2666 | build | later | task-creation map + rail (gated on T-2664 outcome) |
| T-2667 | build | later | knowledge-leveling map + rail (gated on T-2664 outcome) |
| T-2668 | inception (rec **DEFER**) | later | Lock 6 guided-mode procedural enforcement (P3) |
| T-2669 | inception (rec **NO-GO**) | later | P1 audience lenses (functional/technical/pseudocode) |
| T-2670 | inception (rec **DEFER**) | later | Lock 4 Workflow Fabric queryable index |

Gap 7 (P2 consumption weak) is already tracked by active T-2622 — not duplicated.

## 7. SD register — FORMALLY DISPOSED (T-2663 GO, operator via Watchtower, 2026-07-28T17:10Z)

Operator ratified **mirror+rails as the Process layer** (corpus + conformance rails +
overlay; code is the enforced machine, maps must conform). Per-SD dispositions
inherited from that keystone:

| SD | Item | Disposition |
|----|------|-------------|
| SD-1 | Core concepts identity | **GO** — Governance / Value / Process confirmed; Process = corpus + conformance rails + overlay, mirror-direction |
| SD-2 | Own layer vs cross-cutting | Disposed by delivery — own surface (designer corpus + `tools/conformance-registry.yaml`), not a repo-root subsystem |
| SD-3 | Arc↔workflow relation, `workflow:` task binding | **Parked** — mirror direction has no instance semantics; revives only with T-2668 |
| SD-4 | Normative vs descriptive | Disposed **inverted** — code is normative, maps are descriptive-must-conform; T-2619 transitional rule (prose wins) applies only to unrailed maps |
| SD-5 | `workflows/` at repo root | **Retired** — designer store (`.context/designer/projects/`) is the home; single stored representation (T-2608) |
| SD-6 | Ratified immutability | Disposed as delivered — gated promote + version bump + uuid permanence + sha pinning |
| SD-7 | Arc-scoped BVP driver | Superseded — arc-014's proposed drivers (vocabulary-coverage / corpus-fidelity / seam-fluidity) await approval on /arcs/designer-corpus |
| SD-8 | Enforcement ladder advisory→guided→strict | **Retired in original form** — replaced by reverse conformance (daily audited rails); guided/strict parked in T-2668 |
| SD-9 | callActivity node type | Disposed as delivered — collapsed subProcess + cross-map jumps (T-2620 round 3) |
| SD-10 | Instance state home + cage | **Parked** with T-2668 (Q10 autonomy-integrity constraint noted there) |
| SD-11 | humanTouchpoint spec | Partial as delivered — lane→owner, O-1/O-3 veto; richer spec only on demonstrated need |
| SD-12 | Application-practice scope | Retired for now — dogfood only; application rollout unclaimed |
| SD-13 | Component Fabric linkage | **Parked** — zero `components:` refs today; revisit inside T-2670's fabric question |
| SD-14 | Pseudocode lens | Routed to T-2669 (rec NO-GO — no read-pull yet; operator may override) |
| SD-15 | Workflow Fabric | Routed to T-2670 (rec DEFER — no concrete cross-map query need yet) |

With this table the package's register status ("ALL OPEN") is closed: every item is
now GO-ratified, retired, superseded, or parked in a named governed task.

## 8. Provenance RESOLVED + cross-register convergence (832 rails 278/281/285, 2026-07-28)

832 answered the §1 provenance question (rail 281): **the package WAS ingested — 832-side,
same-day (2026-07-02), under their T-019.** The bundled prototype is byte-identical to
their `src/aef-workflow-designer.html` — the package's prototype IS the 832 designer;
lineage runs through their repo. Their T-175 pivot (2026-07-10, → arc-001
designer-authoring-surface, tasks-canonical + mapping-v1) superseded YAML-canonical /
`workflows/`-dir / fw-workflow-verbs without formally disposing SD-1..15 — a bookkeeping
gap they closed with `docs/proposals/aef-workflow-process-layer-2026-07-02/DISPOSITION-2026-07-28.md`
(their T-278). So §1's "never ingested" finding was correct for this repo but half the
picture; the operator's "we ingested it and created an arc" memory was true, 832-side.

**Cross-register dedupe (agreed, rails 285/291):**

| 832 task | AEF task | State both sides | Ownership if revived |
|----------|----------|------------------|----------------------|
| T-279 (guided mode) | T-2668 | DEFER / DEFER | AEF (per 278 split) |
| T-280 (workflow fabric) | T-2670 | DEFER / DEFER | AEF (per 278 split) |
| T-281 (audience lenses) | T-2669 | DEFER / **NO-GO rec** | 832 — divergence surfaced to operator, both filed |
| T-282 (callActivity) | — (SD-9 disposed as delivered) | 832-owned | 832 |
| T-283 (second-tenant example) | — (SD-12 retired here) | **Delivered 832-side** (customer-refund.workflow.yaml, zero-findings first-pass — live V1 data point) | 832 |

**T-2664 pairing article:** 832's corpus already holds `tier0-escalation.workflow.yaml`
(their T-025, with friction note) — designated the 832-side pairing article for the open
tier0 pair-round (rail 287); our draft's raw bytes served at
`/api/version?id=draft-tier0-escalation` (rail 290).
