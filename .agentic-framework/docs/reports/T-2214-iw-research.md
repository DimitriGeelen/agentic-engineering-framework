# T-2214 — IW-5 Spike: Existing-MCP overlap (sibling framework MCP server vs federate into `mcp__skills__*`)

**Parent inception:** T-2209 (Capability-overlay arc: MCP subsystem + CLI route for agent-callable framework primitives)
**Spike worker:** spike-iw5 (TermLink-dispatched, read-only, time-boxed 30 min)
**Methodology:** `docs/dispatch-templates/iw-spike-worker.md` §steps 2-3 (steelman + strawman + BVP)
**Producer ≠ judge.** This is a memo for the operator; no decision is taken here.

---

## Question

> Existing-MCP overlap — should new agent-callable framework primitives ship as a **sibling framework MCP server** (`mcp__framework__*`) or **federate into the existing `mcp__skills__*` server** (`mcp__skills__fw_*`)? What does the surface analysis say?

---

## §1. Surface-overlap inventory (evidence base)

### 1.1 Where the `skills` server actually lives — the decisive fact

From `/opt/999-Agentic-Engineering-Framework/.mcp.json` (in-repo, readable):

```json
"skills": {
  "command": "python3",
  "args": ["/opt/150-skills-manager/skills-mcp-server/server.py"]
}
```

**The skills MCP server is a separate repository — `/opt/150-skills-manager/` — entirely outside the framework's PROJECT_ROOT (`/opt/999-Agentic-Engineering-Framework/`).**

This is not a detail; it is the spine of the analysis. Two framework rules forbid the framework team from editing it:

- **No-cross-repo-edits** (memory `feedback_no_cross_repo_edits`): *"NEVER edit files outside PROJECT_ROOT, send proposals via TermLink."*
- **Path isolation is strict** (memory `feedback_path_isolation_strict`): *"`du`/`find`/`grep`/`cat` on paths outside PROJECT_ROOT are violations."* — this worker did not even *read* `/opt/150-skills-manager/` to gather evidence; doing so would itself violate isolation. The only legitimate evidence about the skills surface is the tool-name list the Claude Code session already exposes.

**Federation (Candidate B), and the federated portion of Candidates C and D, all require committing code into `/opt/150-skills-manager/` — a repo the framework has explicitly walled itself off from.** This is verified-by-construction, not speculative.

### 1.2 Is there any existing framework↔skills code coupling today?

```
grep -rl "150-skills-manager|mcp__skills|skills-mcp" --include=*.sh --include=*.py --include=*.yaml .
```

→ **Zero production-code hits.** Every match is in `docs/reports/*.md` (historical fleet/consumer investigations: T-707, T-601, T-1388, T-1602, …) or the two T-2209/T-2214 artifacts themselves. No `.sh`, `.py`, or `.yaml` in the framework consumes a `mcp__skills__*` tool.

**Conclusion:** federation would create a *new* cross-repo coupling, not extend an existing one. There is no sunk integration to amortise.

### 1.3 The `mcp__skills__*` surface — overlap vs orthogonal split

The skills server exposes ~140 tools (confirmed from this session's MCP tool list). Classified against the framework's primitive surface:

| Skills tool family | Tools | Relation to framework surface |
|--------------------|-------|-------------------------------|
| **`tasks_*`** | `tasks_discover`, `tasks_list_tasks`, `tasks_query`, `tasks_sync`, `tasks_task_status` (5) | **OVERLAPPING by name, divergent by model** — see §1.4 |
| **`orchestrator_*`** | `orchestrator_discover`, `orchestrator_read`, `orchestrator_sync_all`, `orchestrator_sync_designs` (4) | **OVERLAPPING by name** — but `fw orchestrator` is the framework's own dispatch substrate (T-1643/T-1687); name collision, different internals |
| **`knowledge_management_*`** | `index_to_qdrant`, `query_learnings`, `sync_knowledge`, `validate_learnings` (4) | **OVERLAPPING by name** — framework has `fw learnings` / `fw recall` / `fw ask` over file-based `.context/` |
| **`learning_analytics_*`** | `collect_metrics`, `get_recommendations`, `track_application`, `weekly_report` (4) | Partial overlap with `fw metrics` |
| **`errors_*`** | `errors_analyze`, `errors_capture`, `errors_error_status`, `errors_list_errors`, `errors_review` (5) | Partial overlap with `fw healing` / `concerns.yaml` |
| **`project_init_*`** | `init`, `init_cli`, `init_flask`, `init_infra`, `init_mcp`, `generate_skill_section` (6) | Partial overlap with `fw init` / `fw upgrade` |
| **Infrastructure (ORTHOGONAL)** | `proxmox_*` (8), `traefik_*` (4), `certificate_manager_*` (8), `garage_manager_*` (9), `infisical_manager_*` (5), `technitium_manager_*` (12), `pbs_*` (8), `nas_file_service_*` (9), `pihole_*` (1), `zoneedit_manager_*` (5), `remote_exec_*` (6), `alert_dispatcher_*` (4), `onedev_*` (5), `credentials_*` (3) | **NONE** — these are homelab/infra control planes, not governance primitives |

**Overlap density:** ~28 of ~140 skills tools (~20%) are *name-adjacent* to framework primitives; ~80% are infrastructure-orthogonal (proxmox/traefik/certs/garage/dns/backups). This confirms T-2209 §4's estimate (generic ~20%, framework-specific ~80%).

### 1.4 Per-overlapping-tool: same job, or shared name only?

The critical question for federation is whether the existing skills tools *already do* what the framework overlay would do:

- **`mcp__skills__tasks_list_tasks` / `tasks_query` / `tasks_task_status`** — these are *generic, cross-project* task list/status/discovery tools (the skills server is a fleet-wide control plane; its task view is the lowest-common-denominator across many projects). The framework's `fw task list` / `fw task show` / `fw review-queue` return a **richer, framework-specific model**: `horizon` (now/next/later), `bvp_scores`, `arc_id`, `inception_decisions`, partial-complete state, agent-vs-human AC owner split, `[REVIEW]/[REVIEWER]` routing, and class-correct Watchtower URLs (`/inception/<id>` vs `/review/<id>`, per memory `feedback_handoff_url_per_class`). **Same name, materially different data model.** Federating `fw task *` into `tasks_*` means either (a) teaching the skills repo the framework's entire governance model, or (b) flattening framework richness down to the generic skills schema. (a) is a large cross-repo commit; (b) is a capability regression.
- **`mcp__skills__orchestrator_*`** — name-collides with `fw orchestrator` (the framework's own T-1643/T-1687 dispatch substrate with `.context/dispatches.jsonl`, outcome backprop, resolver workflows). These are two unrelated orchestrators that happen to share a noun. Federation here would be actively confusing.
- **`mcp__skills__knowledge_management_query_learnings`** — closest *functional* overlap with `fw recall` / `fw learnings`. But the framework's learnings are file-based in `.context/` (D4 portability: *"learning that lives somewhere non-committed violates D4"* — value-drivers.yaml:79). The skills tool indexes to Qdrant. Federating would risk moving the framework's source-of-truth knowledge into a non-committed store — a **D4 violation**.

**Net:** every overlapping tool shares a *name* but not a *model*. There is no tool where skills "already does what the overlay would do." This removes the only steelman federation has (reuse of existing equivalent behaviour).

---

## §2. Candidates — Steelman + Strawman

### Candidate A — Sibling MCP server (`mcp__framework__*`)

A new framework-owned MCP server, scaffolded inside `/opt/999-Agentic-Engineering-Framework/` (e.g. `mcp-server/server.py`), wired via a new `.mcp.json` block. Independent lifecycle, clean `mcp__framework__*` naming, zero coupling to the skills repo. Two MCP servers live side-by-side.

- **Steelman:** The fix homes where the surface lives. The framework owns `bin/fw`, owns `.tasks/`, owns `.context/`, owns its sovereignty gates (`check-active-task`, `check-inception-recommendation`, `do_inception_decide` refusal). A sibling server keeps every gate framework-side, so the §B-005 / Sovereignty model (T-2209 §3) is preserved without re-implementation. **Precedent exists in-tree:** `.mcp.json` already runs four independent servers (context7, playwright, termlink, skills) side-by-side with zero cross-coupling — adding a fifth is a proven pattern, not a novel architecture. Scope can start minimal: T-2209 §7 Shape-2 (16 read-only verbs, ~22 tools) is well under the ~140-tool skills surface and the 25-tool soft cap. **G-045 Gap Homing is satisfied, not inverted** (see §4).
- **Strawman:** Two servers = two processes to keep healthy, two `fw doctor` surfaces, two startup-failure modes. A naïve agent might call `mcp__skills__tasks_list_tasks` when it wanted `mcp__framework__task_list` — the name-adjacency in §1.3 is a real foot-gun for tool discovery. Mitigation: distinct `framework_` prefix + a `fw doctor` check that both servers resolve. Cost is one new process, not a new auth model (read-only slice uses Candidate D auth = none, per T-2209 §5).

### Candidate B — Federate into `skills` (`mcp__skills__fw_*`)

Extend the skills server with framework-primitive tools, reusing skills' transport/auth/discovery.

- **Steelman:** One server for the operator to manage; reuses skills' MCP transport, tool-discovery, and (Candidate-A-equivalent) auth plumbing — no new process, no second `fw doctor` surface. The skills server is already the fleet-wide control plane an agent reaches for; co-locating framework verbs there means one discovery surface.
- **Strawman (decisive):** **Federation requires committing code into `/opt/150-skills-manager/` — outside PROJECT_ROOT.** This is forbidden by the framework's own `feedback_no_cross_repo_edits` and `feedback_path_isolation_strict` rules; the worker could not even *read* the repo to scope the change. Every future framework primitive change would touch a repo the framework does not own and cannot unilaterally edit — the exact provider/environment lock-in **D4 Portability** exists to prevent (weight 3, value-drivers.yaml:74-79). It also **inverts G-045 Gap Homing** (§4): the framework's surface-exposure fix would home in the skills repo, where no framework agent reads it → zombie-entry risk. Framework sovereignty gates would have to be re-implemented (and kept in sync) inside skills — a silent-drift hazard directly analogous to L-399/T-1890 producer/consumer parity failures. **No existing skills tool actually does the framework's job** (§1.4), so there is not even a reuse dividend to offset the coupling.

### Candidate C — Hybrid (small read-only subset federates, rest sibling)

A handful of universally-useful, framework-language-agnostic read-only verbs federate into skills; everything else lives in a sibling server.

- **Steelman:** Captures the cross-project-discoverability upside for the genuinely generic verbs (e.g. a flattened `tasks_*`-shaped view) while keeping sovereignty-bound and model-rich verbs framework-side. Two-tier: federate where the skills schema already fits, sibling where it doesn't.
- **Strawman:** Worst-of-both on the cross-repo axis — you now maintain **two** coordination surfaces (a sibling server *and* a cross-repo commit stream into skills), and the federated subset still trips the path-isolation wall. You also have to keep the federated read-only view in sync with the sibling's richer view, doubling the drift surface. The "small subset" is exactly the part where skills' generic `tasks_*` already exists (§1.4), so the federated tools would be redundant-but-divergent. Splits cohesion for marginal discoverability gain.

### Candidate D — Defer-and-extend-skills (federate only the clearly-agnostic 20% now, revisit sibling later)

For now add to skills only the surface that is clearly framework-language-agnostic (task discovery, learnings query); revisit a sibling server after that 20% stabilises.

- **Steelman:** Smallest immediate footprint; validates real demand on the agnostic 20% before committing to a whole sibling server. Staged — antifragile-by-deferral (learn from the small surface first). Matches the `feedback_defer_for_evidence_not_confidence` spirit *if* there were a genuine evidence gap about demand.
- **Strawman:** **The "extend skills" half still requires a cross-repo commit into `/opt/150-skills-manager/`** — D inherits B's path-isolation violation, merely at smaller surface area. The framework cannot unilaterally ship even the 20%. Worse, the framework's own `tasks_*`/`learnings` model is *richer* than skills' generic schema (§1.4), so the "clearly agnostic" subset would be a **lossy** projection, not a clean one. And the staging premise is weak: there is no evidence gap about demand — T-2209 §1 already names the consumers (every agent screen-scraping ANSI, every TermLink worker serialising shell strings, every Watchtower POST). The honest staged option is **"sibling read-only slice first" (Candidate A scoped to Shape-2)** — which captures D's incrementalism with zero cross-repo cost. D as literally framed pays the cross-repo tax for a lossy subset; the same caution is better served by A's read-only opening slice.

---

## §3. BVP Scoring Matrix

Active drivers from `policy/value-drivers.yaml` (v3): D1 Antifragility (w9), D2 Reliability (w7), D3 Usability (w5), D4 Portability (w3), F-RECALL Recall Leverage (w6), F-ORCH Orchestration Leverage (w5). Score 0-5 per cell.

| Driver (weight) | A: Sibling | B: Federate | C: Hybrid | D: Defer-extend |
|-----------------|:----------:|:-----------:|:---------:|:---------------:|
| **D1 Antifragility (9)** | 4 — gates stay framework-side; failures isolated to one owned surface | 1 — a skills-repo failure breaks framework surface, and framework *can't fix it* (path isolation) | 3 — mostly sibling; small federated read-only blast | 4 — tiny read-only surface; staged learning before committing |
| **D2 Reliability (7)** | 4 — all sovereignty/agent gates remain in-repo, deterministic | 1 — framework gates must be re-implemented in skills → silent-drift (L-399/T-1890 class) | 3 — sovereignty stays sibling; only read-only federates | 4 — read-only-only ⇒ no gate to drift |
| **D3 Usability (5)** | 4 — clean `mcp__framework__*` naming; proven 4-server side-by-side pattern | 4 — single server to manage; one discovery surface | 3 — two surfaces to reason about; mild cognitive load | 2 — smallest now, but primitives stay mostly shell-only ⇒ agents still screen-scrape |
| **D4 Portability (3)** | 5 — independent MCP-standard server; no skills-repo lock-in | 0 — couples framework to a repo it *cannot edit* — the exact lock-in D4 forbids | 3 — read-only subset coupled, rest portable | 3 — still couples a (lossy) subset cross-repo |
| **F-RECALL (6)** | 2 — could expose `recall`/`learnings` as typed tools; modest | 3 — skills already has `query_learnings`; risks moving SoT off-repo (D4 tension) | 3 — could federate exactly the recall read-verbs | 3 — explicitly targets learnings-query federation |
| **F-ORCH (5)** | 4 — clean typed contract any executor (TermLink/cross-machine) can route to | 3 — typed tools too, but entangled ownership | 4 — routable read-only subset + sibling authority | 2 — minimal now; defers the bigger routable surface |
| **Weighted total** (·weight) | **131** | **69** | **110** | **111** |
| **Normalised** (/175) | **0.749** | 0.394 | 0.629 | 0.634 |

Weighted total = Σ(weight × score); max possible = 35 × 5 = 175.

---

## §4. G-045 Gap Homing — does federation invert the rule?

CLAUDE.md §Gap Homing (G-045): *"A gap belongs in the register where the FIX lives, not where it was HIT. … home the entry where the fix lands."* Worked example: G-045 itself — the framework hit the fleet-cert symptom; TermLink owned the fix; the entry homed in TermLink.

Apply to this arc:
- **The symptom** (agents screen-scrape `bin/fw` ANSI output; TermLink workers serialise shell strings; Watchtower POSTs argv-shaped payloads) is **hit inside the framework**, by framework-owned consumers.
- **The fix** (typed tool schemas over framework primitives) belongs **wherever the framework primitives are defined** — i.e. `/opt/999-Agentic-Engineering-Framework/`. The framework *owns* `bin/fw`, `.tasks/`, `.context/`, and the sovereignty gates.

Therefore:
- **Candidate A (sibling) HOMES the fix correctly** — fix lands in the repo that owns the surface. G-045-aligned.
- **Candidate B (federate) INVERTS G-045** — the fix would land in `/opt/150-skills-manager/` (skills repo), which neither owns the framework primitives nor is read by framework agents. That is precisely the "zombie entry nobody who could fix it will ever read" failure G-045 warns against, transposed from concern-registers to code. Candidates C and D inherit the inversion for their federated portions.

**G-045 is a clean structural argument for A and against B/C/D's federated surface.** This is not a preference — it is the framework's own homing rule applied to its own surface.

---

## §5. Cost Estimates (F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort)

T-shirt mapping per template: S=2, M=4, L=6, XL=8.

| Candidate | blast_radius | tier | effort | **F8** | Note |
|-----------|:------------:|:----:|:------:|:------:|------|
| **A: Sibling** | 4 (M) — new in-repo process + `.mcp.json` block; read-only slice first | 2 — read-only opening slice, no new auth | 6 (L) — full server; less for Shape-2 read-only slice | **3.6** | All cost stays in-repo; incremental via Shape-2 |
| **B: Federate** | 8 (XL) — cross-repo commit into a repo framework *can't read or edit* + gate re-implementation | 6 — cross-repo sovereignty coordination | 8 (XL) — teach skills the full governance model | **7.4** | Highest blast; requires the forbidden cross-repo edit |
| **C: Hybrid** | 6 (L) — sibling server **and** cross-repo subset = two coordination surfaces | 4 | 6 (L) | **5.4** | Worst-of-both coordination overhead |
| **D: Defer-extend** | 4 (M) — small but still cross-repo; lossy projection of richer model | 4 — cross-repo even for the subset | 2 (S) — small surface | **3.8** | Small footprint but still trips path-isolation |

**Value/cost ratio:** A = 131/3.6 = **36.4** · D = 111/3.8 = 29.2 · C = 110/5.4 = 20.4 · B = 69/7.4 = 9.3.

**A dominates on both axes** — highest value (131) *and* lowest cost (3.6). It is not a value-vs-cost trade; A is the Pareto winner.

---

## §6. Recommendation

**Recommend Candidate A — sibling framework MCP server (`mcp__framework__*`), opened as a read-only slice (T-2209 §7 Shape-2).**

One-sentence rationale: A is the Pareto winner (value 131 / cost 3.6, ratio 36.4 — best on both axes), it is the **only** candidate that does not require editing `/opt/150-skills-manager/` — a repo the framework's own path-isolation and no-cross-repo-edits rules forbid it from touching — and it **homes the fix where the surface lives** per G-045, whereas B/C/D invert Gap Homing and pay a cross-repo D4-portability tax (B scores **0** on D4) for a *lossy* projection of a model skills does not actually replicate (§1.4: same names, different data model).

**Staging note (replaces Candidate D's premise):** D's instinct — start small, validate before committing — is sound, but D executes it via the forbidden cross-repo path. The correct staged opening is **A scoped to Shape-2**: 16 read-only verbs (`task_list`, `task_show`, `review_queue`, `inception_status`, `bvp_rank`, `learnings`, `recall`, `gaps`, `metrics`, `doctor`, `fabric_search`, `costs`, `version`, …), Candidate-D auth (none — read-only), one new `.mcp.json` block, headline mechanic **HM-B** (T-2209 §6). This captures D's incrementalism with zero cross-repo cost and zero new sovereignty surface.

**Not a hedge — this is GO-shaped evidence for A.** The decisive facts are verified-by-construction (the skills repo path from `.mcp.json`; the zero existing coupling from grep; the path-isolation prohibition from CLAUDE.md), not confidence-gaps. The operator decision is *which slice scope and which headline mechanic*, not *sibling-vs-federate* — federation is structurally foreclosed by the framework's own rules.

---

## §7. Open Sub-Questions (surfaced, out of this spike's scope)

1. **Name-collision mitigation (D3 foot-gun):** `mcp__framework__task_list` vs `mcp__skills__tasks_list_tasks` are name-adjacent. Should the framework server use a longer disambiguating prefix, and should `fw doctor` warn when both servers expose adjacent task verbs? → feeds IW-2 (verb scope) / IW-4 (headline mechanic).
2. **Should the framework *retire* reliance on `mcp__skills__tasks_*` for its own tasks?** If a sibling `mcp__framework__task_*` ships, the generic skills task view becomes redundant *for framework projects* (though still useful fleet-wide). Not this spike's call — flag for the arc decision.
3. **Auth for the agent-authority tier** (Shape-3, beyond read-only): deferred to IW-3 (T-2209 §5). Read-only slice (this recommendation) needs no auth; the authority tier does.
4. **`knowledge_management`/`recall` D4 tension:** if any recall verb is ever exposed, it must keep `.context/` file-based as source-of-truth (value-drivers.yaml:79) and never delegate SoT to skills' Qdrant index. Design constraint for whoever ships F-RECALL-touching tools.

---

*Spike complete. Read-only; no source edits; no `.mcp.json` changes; no Sovereign acts. Path isolation honoured — `/opt/150-skills-manager/` was identified from in-repo `.mcp.json` only and never read. Producer ≠ judge: this memo informs the operator's IW-5 disposition on T-2209; it does not decide it.*
