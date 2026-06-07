# T-2210 — IW-1 Delivery-shape research spike

**Parent inception:** T-2209 (Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework primitives)
**Spike question:** IW-1 — which delivery shape does the arc produce?
**Status:** research memo for operator. Producer ≠ judge — no Sovereign acts taken. Filed 2026-06-05.
**Method:** template `docs/dispatch-templates/iw-spike-worker.md` §Worker-contract steps 2–3. Inventory data reused from parent artifact `docs/reports/T-2209-cli-mcp-overlay-inception.md` §3/§4/§5/§7 (not re-derived).

---

## Question

> MCP server vs CLI-overlay vs both-as-siblings vs federate-into-skills — which delivery shape does the arc produce?

Four named candidates:

- **A. MCP-server-only** — a new framework MCP server (stdio JSON-RPC per Anthropic spec) exposing `fw` primitives as typed tools. Maps to parent §7 Shape-2/Shape-3.
- **B. CLI-overlay-only** — `--json` output mode + machine-callable surface on existing `bin/fw` verbs; no new server process. Maps to parent §7 Shape-1.
- **C. Both-as-siblings** — MCP server AND CLI overlay shipping together, both consuming the same `fw --json` underlay. Maps to parent §7 Shape-4.
- **D. Federate-into-skills** — extend the existing `mcp__skills__*` server with framework primitives instead of building a new MCP server. Maps to parent §7 Shape-5.

---

## Candidates

### A. MCP-server-only

#### Steelman
- **D4 directive explicitly names the standard.** `policy/value-drivers.yaml:74-79` (D4 Portability) and CLAUDE.md §Four Constitutional Directives both say *"prefer standards (MCP, LSP, OpenAPI)."* A native MCP server is the canonical portable interface — an MCP client on any host (Claude Code, future agents) calls typed tools with discoverable schemas, zero ANSI screen-scraping.
- **Precedent is already in-session.** The running session loads four MCP servers (`claude-in-chrome`, `context7`, `skills`, `termlink` — parent artifact §4). A framework MCP server would be the Nth, not the first; the integration pattern is proven (`.mcp.json` already exists, 24 lines, confirmed present).
- **F-ORCH win.** Exposing `fw` primitives as typed MCP tools directly raises the routable surface a non-primary executor can call — `policy/value-drivers.yaml:131-141` rubric level 3-4 ("clean typed I/O contract … so the framework can refuse-or-dispatch the step mechanically").
- **Bounded scope exists.** Parent §3 already curated a ~22-tool minimal set (16 read-only + 6 agent-authority) under the 25-tool soft cap — the server need not expose all 129 verbs.

#### Strawman
- **New process = new failure class (D1/D2 hazard).** A separate server has its own lifecycle, transport, and crash modes that the shell surface does not. Antifragility (D1, weight 9) is not advanced by adding surface; reliability (D2, weight 7) gains typed schemas but loses a single-process guarantee.
- **Sovereignty boundary is unresolved (§B-005).** Parent §5 (Spike 3) shows stdio JSON-RPC carries **no agent identity by default**. Candidate-A "env-inherit `$CLAUDECODE`" auth is *"trivially spoofable … the silent default operators often regret"* (T-2209 §5, ranked weakest). Exposing agent-authority verbs through MCP before the auth question (IW-3 / T-2212) is settled risks re-opening a §B-005-class surface.
- **Headline-mechanic hazard (§ACD / G-062).** "MCP server exists and accepts calls" is substrate-phrased — the exact conflation that burned T-1626/T-1641/T-1670 (CLAUDE.md §Arc Completion Discipline). A server-first arc invites that trap.

### B. CLI-overlay-only

#### Steelman
- **Additive to an established pattern, not greenfield.** `grep` finds **33 `--json` handling sites already live** across `bin/fw` and `lib/` (verified this spike: `lib/resolver.py`, `lib/ask.{py,sh}`, `lib/gaps.py`, `lib/outcome.py`, `lib/bvp.sh`, `lib/reviewer/dispatch_cli.py`, `agents/termlink/bvp-estimator/estimator.py`). CLAUDE.md Quick Reference confirms `fw orchestrator status --json`, `fw resolver dispatch --json`, `fw outcome evaluate --json`, `fw reviewer T-XXX --dispatch --json`. Extending `--json` to the curated read-only set is *finishing a pattern the codebase already practises*, not inventing one.
- **Every existing gate survives unchanged (D2 win, weight 7).** A `--json` flag is a presentation layer on the *same* dispatch path — `check-active-task`, `check-tier0`, `check-inception-recommendation`, focus-drift, budget-gate all fire identically (parent A2/A3). No gate needs re-implementing through a new transport. This is the single biggest reliability argument.
- **Zero new auth surface.** Parent §5 Candidate D ("shell-only, no MCP") is rated *"trivially safe"* — no token store, no `$CLAUDECODE` spoofing vector, no new sovereignty surface to protect.
- **Honest §ACD headline mechanic is cheapest.** Parent §6 HM-A: *"an agent invokes `fw task show T-2204 --json | jq '.recommendation.verdict'` and observes `\"GO\"`, identical to what the operator sees on `/inception/T-2204`"* — one shell command, wire-level, deliverable-phrased. Satisfies G-062 with the smallest demo.
- **It is the substrate C and A both need anyway.** A thin MCP server (Candidate A/C) wrapping `fw --json` is near-trivial (parent §7: *"a thin MCP server can wrap `--json` CLI verbs almost trivially"*). B-first is the de-risking spine for any later MCP work.

#### Strawman
- **Loses typed-tool ergonomics for MCP clients (D4 partial).** JSON-on-stdout is portable but is *not* a discoverable interop standard the way MCP's `tools/list` is. An MCP client must still know the verb names and argv shape; there is no schema handshake. D4 (weight 3) is only partly served.
- **Watchtower/agent parsing still string-couples.** Consumers parse a JSON blob keyed to CLI output shape; a verb's output-schema change can still break a downstream parser silently (weaker than a versioned tool schema).
- **F-ORCH ceiling is lower than A/C.** Adds a machine-callable surface (level 3) but no schema-discovery or dispatch-decision tree (no level-4/5 uplift) — `policy/value-drivers.yaml:131-141`.

### C. Both-as-siblings

#### Steelman
- **Highest combined value.** Ships the portable JSON shell surface (B) *and* the MCP standard (A), both reading the same `fw --json` underlay (parent §7 Shape-4) — so the MCP server is a thin wrapper, not a parallel implementation (honours parent A1: overlay is a *projection*, never a second authority surface).
- **Serves every consumer named in the problem statement** (T-2209 §Problem Statement): shell agents (JSON), MCP clients (typed tools), Watchtower frontend (structured response), cross-machine TermLink workers — in one arc.
- **Strongest F-ORCH** (both routable surfaces) and **strongest D4** (both the file/shell-portable and the MCP-standard interfaces).

#### Strawman
- **Highest blast radius and slice count** (parent §7: 6-8 slices) — directly the unbounded-scope hazard G-020 warns the inception against. Two surfaces to keep in sync = a drift class (the JSON underlay and the MCP wrapper can diverge).
- **Forces the IW-3 auth question immediately.** Shipping the MCP leg means the §B-005 auth model (T-2212) must be resolved *now*, not deferred — couples this arc's timeline to an unsettled Sovereignty decision.
- **§ACD risk doubles** — two headline mechanics (HM-A + HM-B) to demo; more surface to substrate-conflate.

### D. Federate-into-skills

#### Steelman
- **Cheapest *if* the surface were already mostly present.** Parent §4 found `mcp__skills__tasks_*` (5 tools), `orchestrator_*` (4), `knowledge_management_*` (3), `learning_analytics_*` (4) — generic task/knowledge primitives that *look* like framework overlap. If skills already hosted 80% of the primitives, federation would be "migrate the remaining 20%."
- **One fewer server to run** — reuses an existing transport already loaded in-session.

#### Strawman (decisive)
- **The 80/20 is inverted.** Parent §4 measured overlap density: *"generic ~20%, framework-specific ~80%."* `mcp__skills__tasks_*` exposes generic discover/list/query/sync/status; the framework's `fw task list / review-queue` return horizon, BVP scores, partial-complete state, agent-vs-human owner split, Watchtower URLs — none of which skills models. Federation would mean **teaching another project's server the entire AEF data model** (parent §4: *"Federation would entangle frameworks"*).
- **Violates No-Cross-Repo-Edits + Gap-Homing.** The `skills` server lives in another repo; the fix would land *there*, not in PROJECT_ROOT (memory [[feedback_no_cross_repo_edits]]; CLAUDE.md §Gap Homing — *"a gap belongs where the FIX lives"*). This is the exact provider/repo entanglement D4 (weight 3) forbids: *"No provider/language/environment lock-in."*
- **Inherits skills' weakest auth** (parent §5 Candidate A class) while *raising* the sovereignty stakes — the AEF gates are stricter than its MCP neighbours (parent §5), so importing the framework's privileged verbs into a server that owns neither the gates nor the data model is the worst Sovereignty posture of the four.
- **Cross-repo coordination cost is unbounded** — requires the skills-server owner in the loop; parent §7 marks Shape-5 as *"requires upstream coordination."* That is the open-ended scope G-020 exists to refuse.

---

## BVP Scoring Matrix

Drivers and weights from `policy/value-drivers.yaml` (D1=9, D2=7, D3=5, D4=3, F-RECALL=6, F-ORCH=5; total weight 35). Score 0-5 per cell; one-line reasoning below the table.

| Candidate | D1 Antifragility (9) | D2 Reliability (7) | D3 Usability (5) | D4 Portability (3) | F-RECALL (6) | F-ORCH (5) | **Weighted /35** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **A. MCP-only** | 2 | 3 | 2 | 4 | 1 | 4 | **2.49** |
| **B. CLI-overlay** | 3 | 4 | 3 | 3 | 1 | 3 | **2.86** |
| **C. Both-siblings** | 2 | 4 | 3 | 4 | 1 | 5 | **2.97** |
| **D. Federate-skills** | 1 | 2 | 2 | 1 | 1 | 2 | **1.49** |

**Per-cell reasoning:**

- **D1 (Antifragility):** A/C add a new server process = new failure class (2); B is additive-only, no new crash surface, but doesn't strengthen-under-stress either (3); D entangles two repos = most fragile (1).
- **D2 (Reliability):** B reuses the *same* dispatch path so every gate fires unchanged — highest single reliability argument (4); C same on its CLI leg but adds a sync-drift class between two surfaces (4); A trades ANSI-parse errors for new-process lifecycle risk (3); D inherits skills' weakest auth + cross-owner drift (2).
- **D3 (Usability):** D3 is *human* ergonomics — all four are primarily agent-facing; B/C also feed the Watchtower frontend (structured response replacing argv-shape POST → ANSI shell-out, parent §6 HM-E) (3); A/D give no new human surface (2).
- **D4 (Portability):** A/C ship the named MCP standard the directive explicitly prefers (4); B is portable JSON but not a discoverable interop standard (3); D entangles framework with another repo's server = the lock-in D4 forbids (1).
- **F-RECALL (positive-accumulation):** none of the four builds durable retrievable knowledge — all score the no-signal floor (1).
- **F-ORCH (routable-surface):** C exposes both routable surfaces incl. typed MCP tools = level 5 (5); A typed MCP tools = level 4 (4); B machine-callable JSON contract but no schema discovery = level 3 (3); D expands surface only via another's server, 80% data-model gap = level 2 (2).

---

## Cost Estimates

`F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort`. T-shirt → S=2 / M=4 / L=6 / XL=8. Blast-radius/effort anchored on parent §7 slice counts; tier reflects auth/sovereignty surface introduced.

| Candidate | blast_radius | tier | effort | **F8 cost** | Anchor |
|-----------|:---:|:---:|:---:|:---:|---|
| **A. MCP-only** | 4 (M) | 4 | 6 (L) | **4.20** | parent §7 Shape-2/3: 4-9 slices; new server + auth surface |
| **B. CLI-overlay** | 2 (S) | 2 | 4 (M) | **2.20** | parent §7 Shape-1: 3-4 slices; additive `--json`, no new auth |
| **C. Both-siblings** | 6 (L) | 4 | 6 (L) | **5.40** | parent §7 Shape-4: 6-8 slices; B underlay + MCP wrapper + auth |
| **D. Federate-skills** | 6 (L) | 4 | 8 (XL) | **5.60** | parent §7 Shape-5: cross-repo coordination, unbounded |

**Value-per-cost (weighted BVP ÷ F8):** B = 1.30 · C = 0.55 · A = 0.59 · D = 0.27.

---

## Recommendation

**Preferred candidate: B — CLI-overlay-only**, as the arc's opening deliverable.

**One-sentence rationale:** B carries the highest BVP (2.86, beating A's 2.49 and trailing C's 2.97 by only 0.11) at the lowest cost (F8 2.20, less than half of C/D) — a value-per-cost of 1.30 versus ≤0.59 for every alternative — *because* it reuses the established 33-site `--json` pattern with every existing gate firing unchanged (the D2 win), adds zero auth surface (parent §5 "trivially safe"), and is the exact `fw --json` underlay that Candidate C would have to build first anyway, making B-first the de-risking spine toward C rather than a competing path.

**Sequencing note (not a Sovereign act — for operator's consideration):** C is the higher-value end-state, but its 0.11 BVP edge does not justify 2.5× the cost or forcing the unresolved IW-3 auth decision (T-2212) into this arc's critical path. Ship B; if the HM-A headline mechanic proves out and the operator wants typed MCP tools, a thin wrapper over the B underlay evolves B→C at the *then*-known auth posture. **D is dominated on every axis** (lowest value 1.49, highest cost 5.60) and additionally violates No-Cross-Repo-Edits and D4's lock-in prohibition — eliminate it. This is a GO-grade recommendation, not a DEFER: the evidence (inventory §3, overlap §4, auth §5, shapes §7, plus this spike's 33-site `--json` verification) is complete for the delivery-shape question.

---

## Open Sub-Questions

Surfaced but out of this spike's scope (route to the named sibling spike):

1. **Exact curated verb list (IW-2 / T-2211).** This spike assumes parent §3's ~22-tool set; T-2211 owns the curated-22-vs-40-vs-129 classification rule. B's blast-radius (S=2) holds only if scope stays near the read-only-16 + agent-authority-6 set.
2. **Auth model for any future MCP leg (IW-3 / T-2212).** B needs *no* auth (shell-only). The moment a B→C evolution adds the MCP server, the §B-005 env-inherit-vs-token-vs-handshake decision (parent §5 Candidates A/B/C/D) becomes blocking. Deferring the MCP leg defers this cost — a structural argument *for* B-first.
3. **Headline mechanic selection (IW-4 / T-2213).** This spike's value rests on HM-A (parent §6) being the chosen demo. If the operator picks a round-trip (HM-D) or Watchtower-frontend (HM-E) mechanic, B's scope may widen — re-check the F8 then.
4. **Output-schema stability contract.** B's strawman (string-coupled JSON parsing) implies a follow-up: should `fw --json` carry a `schema_version` field so downstream parsers fail loud, not silent? Out of scope here; flag for the build slice.
5. **F-RECALL is floored at 1 for all four.** The delivery-shape decision is orthogonal to durable-knowledge capture. If the operator wants the arc to *also* advance F-RECALL (weight 6), that is a separate scope addition, not a property of any delivery shape.
