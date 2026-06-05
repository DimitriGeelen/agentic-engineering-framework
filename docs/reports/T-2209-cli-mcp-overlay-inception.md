# T-2209 — Capability-overlay arc: MCP subsystem + CLI route for agent-callable framework primitives

**Status:** inception, exploration phase, no decision yet (filed 2026-06-05 with `Recommendation: DEFER` pending operator input on IW-1..IW-5)

**Why this artifact exists:** C-001 enforcement — the research trail IS the artifact. Conversations are ephemeral; this file is permanent. Updated incrementally as spikes produce findings; committed after each segment.

---

## §0. Filing context

The operator directive that triggered this inception, verbatim from chat:

> *"proceed as seen fit, prioritize High value / low cost BCP tasks, continue until context is at 300k, apply framework governance !!! use termlink whwre sensible and possible ->> check messages --> focus on new MCP subsystem & CLI arc"*

Filing was per G-020 — the directive describes >3 new files, new subsystem (MCP server process), new CLI route (overlay), potential secret handling (per-client auth tokens). Build was prohibited until inception decide.

A prior in-conversation reference to `HANDOFF-cli-mcp-overlay-2026-06-02 v3` was found absent from disk on 2026-06-05 verification (grep across `.context/handoffs/`, `inbox/`, pickup processed archive, full-repo `*.md`/`*.yaml`/`*.txt` returned zero matches). That handoff is treated as a memory phantom unless/until a real source file appears. **This inception is grounded in the directive above, not in the phantom.**

---

## §1. Problem framing (mirror of T-2209 §Problem Statement)

The framework already speaks MCP — the running Claude Code session has `claude-in-chrome`, `context7`, `skills`, and `termlink` MCP servers loaded. The framework's own surface (`bin/fw …`) is shell-only; agents reach it via `Bash` tool calls.

**The arc question:** should the framework expose its own primitives — `fw task review`, `fw inception start`, `fw arc create`, `fw bvp`, `fw reviewer`, `fw cron`, `fw handover`, etc. — through:

1. **An MCP server** (typed tool schemas, JSON returns, capability discovery), and/or
2. **A "CLI route" overlay** (structured JSON output on top of existing verbs, idempotent invocation, request IDs)

**For whom:** every agent that today shells out to `bin/fw <verb>` and screen-scrapes ANSI-coloured output, every cross-machine TermLink worker that today serialises requests as shell command strings, every Watchtower frontend that today builds POST payloads matching CLI argv shape.

---

## §2. Spikes (planned — output rendered below as they complete)

| # | Title | Time-box | Output anchor |
|---|-------|----------|---------------|
| 1 | Surface inventory: every fw verb, Sovereignty/agent-auth/read-only classes | 30 min | §3 |
| 2 | Existing-MCP-surface inventory + overlap map | 20 min | §4 |
| 3 | Authentication design candidates | 30 min | §5 |
| 4 | Headline-mechanic candidates (3-5 wire-level demos for operator pick) | 20 min | §6 |
| 5 | Arc-shape candidates (MCP-only, CLI-only, both-as-siblings) | 10 min | §7 |

**Total budget:** ~2 hours of read-only research. No source edits during exploration. All `bin/fw` source remains untouched until `fw inception decide T-2209 go` lands an explicit GO.

---

## §3. Spike 1 — Surface inventory (output)

`bin/fw` has **129 top-level dispatch branches**, grouped (per `fw help`) into 7 categories:

- **Workflow:** `task`, `inception`, `assumption`, `work-on`, `review-queue`, `verify-acs`, `promote`, `fix-learned`
- **Context:** `context init|focus|add-learning|add-pattern|add-decision|generate-episodic`, `consolidate`
- **Authority:** `tier0`, `approvals`, `enforcement`, `notify`
- **Delivery:** `git`, `push`, `handover`, `handover --checkpoint`, `healing`, `resume`, `bus`, `dispatch`, `pickup`, `peer`, `mcp` (process reaper, not a server), `dispatch`, `pickup`, `serve`, `deploy`, `cron`, `scan`
- **Knowledge:** `ask`, `recall`, `search`, `docs`, `decisions`, `learnings`, `patterns`, `practices`, `timeline`, `gaps`
- **Setup:** `init`, `upgrade`, `update`, `vendor`, `hook`, `hook-enable`, `harvest`, `termlink`, `onboarding`
- **Diagnostics:** `doctor`, `metrics`, `audit`, `costs`, `self-audit`, `self-test`, `test`, `validate-init`, `version`, `preflight`, `plugin-audit`, `traceability`

Sovereignty / authority classification (preliminary — to be refined with hook source):

| Class | Examples | Gates that must survive any overlay |
|-------|----------|-------------------------------------|
| Sovereignty-bound (agent-blocked under `$CLAUDECODE=1`) | `bvp confirm`, `inception decide`, `arc close`, force-pushes, `tier0 approve`, `enforcement baseline` (B-005) | `check-tier0`, do_inception_decide refusal, do_arc_close refusal |
| Agent-authority (state-changing, agent-allowed) | `work-on`, `task update`, `cron generate`, `cron install` (root-required), `audit`, `note`, `assumption add`, `context add-learning` | `check-active-task` (G-013), `check-inception-recommendation` (T-2205), G-067 disposition gate, G-020 placeholder-AC gate, focus-drift gate, budget-gate, boundary-hook |
| Read-only / advisory | `bvp` (rank), `inception status`, `task list/show`, `review-queue`, `metrics`, `doctor`, `audit` (read), `learnings`, `practices`, `decisions`, `timeline`, `ask`, `recall`, `search`, `docs`, `gaps`, `fabric overview/deps/impact/search`, `costs`, `version` | No gating needed; safe to expose unconditionally |

**Curated minimal set for an MCP overlay** (estimated by §ACD discipline — small enough to demo headline mechanic without rewriting half the framework):

- Read-only: `task_list`, `task_show`, `review_queue`, `inception_status`, `bvp_rank`, `learnings`, `decisions`, `recall`, `ask`, `gaps`, `metrics`, `doctor`, `fabric_search`, `fabric_deps`, `costs`, `version` (~16 tools)
- Agent-authority: `work_on`, `task_update`, `note`, `context_focus`, `context_add_learning`, `assumption_add` (~6 tools)
- Total target: **~22 tools** — under the 25-tool soft cap that keeps `claude --help` parseable, well under `mcp__skills__*`'s ~140

Sovereignty-bound verbs stay shell-only (`bin/fw`) — exposing them via MCP would require an auth model the framework does not yet have. Listed as out of scope for the first arc.

## §4. Spike 2 — Existing MCP surface overlap (output)

The Claude Code session's MCP server descriptors (from session-start system reminder, counted by tool-name prefix):

| Server | Tool count | Surface theme | Framework-overlap candidates |
|--------|-----------|---------------|------------------------------|
| `claude-in-chrome` | 27 | Browser automation, tabs, find/click/upload | none |
| `context7` | 2 | Library docs query | none (advisory) |
| `skills` | ~140 | Cross-project: alerts/certs/garage/infisical/kcp/learning/nas/onedev/orchestrator/pbs/pihole/proxmox/remote-exec/tasks/technitium/traefik/zoneedit | **`mcp__skills__tasks_*` (5 tools), `mcp__skills__orchestrator_*` (4 tools), `mcp__skills__learning_analytics_*` (4 tools), `mcp__skills__knowledge_management_*` (3 tools)** |
| `termlink` | ~220 | Session/agent/inbox/channel/spawn/dispatch primitives | none — TermLink is the transport layer, not the framework surface |

**`mcp__skills__tasks_*` already covers:** `tasks_discover`, `tasks_list_tasks`, `tasks_query`, `tasks_sync`, `tasks_task_status` — these are *generic* task-listing / status / discovery. The framework's `fw task list`, `fw task show`, `fw review-queue` are richer (return horizon, BVP scores, partial-complete state, agent-vs-human owner split, Watchtower URLs).

**Overlap density estimate:** generic ~20%, framework-specific ~80%. Federation into `skills` would require teaching `skills` the framework's data model (horizon, BVP, arc_id, inception_decisions, review markers). Greenfield framework MCP server keeps the model where it lives.

**IW-5 partial answer:** sibling MCP server is structurally cleaner. Federation into `skills` would entangle frameworks; sibling preserves the §B-005 / sovereignty model where each surface owns its gates.

## §5. Spike 3 — Auth candidates (sketches only — sovereignty boundary)

| Candidate | Mechanism | Pro | Con | Sovereignty stance |
|-----------|-----------|-----|-----|-------------------|
| A: env-inherit | MCP server reads `$CLAUDECODE` / `$AI_AGENT` from spawn env | Zero config; uniform with shell `bin/fw` | Trivially spoofable by misconfigured `.mcp.json`; conflates "running under Claude Code" with "is an authorised agent" | Weakest |
| B: per-client token | `.mcp.json` carries `args: ["--token", "<uuid>"]`; server validates against `.context/working/.mcp-tokens.yaml` | Explicit; per-client revocation | Token storage = new sovereignty surface; rotation lifecycle is real cost | Medium |
| C: capability handshake | Client sends `initialize` with declared capability list; server returns allowed subset based on signed manifest | Most precise; per-tool authorisation | High implementation cost; novel for the framework | Strongest, most code |
| D: shell-only (no MCP) | Skip MCP server; only ship CLI-route overlay (`--json`) | Zero new auth surface | Loses the typed-tool ergonomics for MCP clients | Trivially safe |

**Recommend candidate D first**, then Candidate A only after operator chooses an explicit risk position. Candidate A is the silent default that operators often regret — the framework has burned three §B-005-class surfaces this quarter already.

## §6. Spike 4 — Headline-mechanic candidates (for operator to pick)

Per G-062 §ACD discipline: arc closure requires a wire-level demo. Below are 5 candidates, all phrased deliverable-not-substrate:

- **HM-A (CLI-overlay only):** *"An agent invokes `fw task show T-2204 --json | jq '.recommendation.verdict'` and observes `\"GO\"`, identical to the value the operator sees on `/inception/T-2204`."* Smallest scope; zero new processes; demo is one shell command.
- **HM-B (MCP read-only):** *"Claude Code calls `mcp__fw__review_queue()` and observes the same task list (with the same verdicts and ages) that `bin/fw review-queue` prints, including a delta detection for newly-arrived partial-completes."*
- **HM-C (MCP authority):** *"Claude Code calls `mcp__fw__work_on(name, type)` and the operator observes a new task file in `.tasks/active/` with the same content `fw work-on` would have produced — including all G-020 / T-1716 / G-067 gate firing if applicable."*
- **HM-D (round-trip):** *"A TermLink-spawned worker on a sibling project calls `mcp__fw__pickup_send(...)` to hand a result back to this framework's pickup pipeline; the framework's `fw pickup status` shows the inbound transfer within 60s."*
- **HM-E (Watchtower-frontend overlay):** *"Watchtower POSTs JSON to a local CLI-overlay endpoint and recovers structured task metadata for `/tasks/T-XXX` rendering, replacing today's argv-shape POST → ANSI-output shell-out pattern."*

**Operator names exactly one of HM-A..HM-E** (or proposes HM-F). This anchors the §ACD discipline; without it, the arc cannot ship per G-062.

## §7. Spike 5 — Arc shape candidates (output)

| Shape | Spike-1 verb scope | Slice count (est) | Auth model | Headline mechanic |
|-------|---------------------|-------------------|-----------|-------------------|
| Shape-1: CLI-overlay-only | ~22 fw verbs gain `--json` mode + machine-callable exit codes | 3-4 (read-only slice, agent-authority slice, sovereignty boundary slice, docs slice) | Candidate D (none — shell-only) | HM-A |
| Shape-2: MCP-server-only (read-only) | 16 read-only fw verbs exposed as MCP tools | 4-6 (server scaffold, read-only tools, .mcp.json wiring, doctor surface, docs) | Candidate D / A | HM-B |
| Shape-3: MCP-server-full (read + agent-authority) | 22 fw verbs as MCP tools | 6-9 (Shape-2 + 6 agent-authority tools + gate-firing through MCP transport + bypass-env audit log integration) | Candidate A or B | HM-C |
| Shape-4: Both siblings | Shape-1 + Shape-2 ship together; both consume the same `fw --json` underlay | 6-8 | Candidate D | HM-A + HM-B verified in same demo |
| Shape-5: Federate into `skills` | Extend `mcp__skills__tasks_*` to cover framework-specific verbs | n/a — requires upstream coordination with the `skills` MCP server owner | inherits skills' (Candidate A) | HM-E variant |

**Recommend Shape-1 or Shape-4 as opening candidate** — both keep auth surface trivial (Candidate D) and produce an honest §ACD demo (HM-A). Shape-3 has the highest blast radius and is where the sovereignty-bound discussion would need to happen explicitly.

---

## §8. Open Questions (mirror of T-2209 §Open Questions)

- **IW-1: MCP server vs. CLI-route overlay vs. both?** → DEFERRED, needs operator
- **IW-2: Verb scope — all ~70 or curated 10-20?** → DEFERRED, depends on IW-1
- **IW-3: Auth model — env inheritance / token / handshake?** → DEFERRED, Sovereignty-bound
- **IW-4: Headline mechanic (G-062 §ACD)?** → DEFERRED, operator names it
- **IW-5: Existing-surface overlap with `skills` MCP server — federate or sibling?** → DEFERRED, Spike 2 input

Per [[feedback_defer_for_evidence_not_confidence]] discipline: each DEFER above is genuine evidence-gap, not hedge. The arc's shape (single-deliverable vs multi-slice, MCP-vs-CLI vs both, scope of verbs) cannot be answered from the artifact alone; the operator's preference materially changes the candidate space.

---

## §9. Dialogue log

### 2026-06-05 — Initial filing
- **Operator directive:** *"focus on new MCP subsystem & CLI arc"* (verbatim above)
- **Agent response:** Filed as inception T-2209 per G-020 (new subsystem + CLI route triggers fire). `Recommendation: DEFER` set at filing time per T-1716 gate, honest about evidence-gap on IW-1..IW-5.
- **Surface check:** No handoff file on disk; prior memory reference (`HANDOFF-cli-mcp-overlay-2026-06-02 v3`) corrected as phantom in [[project_t2204_completed_4_of_4_plus_cron]] sibling memory.
- **Next:** spikes 1-5 (read-only), then `fw task review T-2209` to surface candidates to operator for IW-1..IW-5 disposition.

### 2026-06-05 — Operator records GO; agent surfaces decision-rationale-vs-text contradiction
- **Operator action:** GO recorded via Watchtower at `2026-06-05T14:36:44Z`. Decision Rationale text on file is the filing-time DEFER text verbatim (template artifact, not new operator scope).
- **Agent response:** Stopped — refused to synthesise IW-1..IW-5 answers under inception discipline + §ACD G-062 (headline mechanic must be operator-named) + Producer ≠ judge. Surfaced the contradiction back to operator.
- **Operator directive:** *"for all iw1 bis iw5 send out a temlink agent for each to research, score against business value drivers, stellman and strawman and then report back to be and take me through each step by stepp, ensure we put a struicture ion palce to support this if needed break down in further tasks under the inception arc"*
- **Agent response:** Filed 5 spike children T-2210..T-2214 (workflow_type: specification), wrote reusable worker template at `docs/dispatch-templates/iw-spike-worker.md`, wired T-2209 `inception_decisions:` per T-1984 GO-scope traceability, dispatched 5 TermLink workers in parallel.

### 2026-06-05 — IW-1..IW-5 spike results returned; cross-spike tension surfaced
- **Workers complete:** All 5 produced research artifacts at `docs/reports/T-22{10,11,12,13,14}-iw-research.md` (~15K each). Workers skipped bus-post step (artifact-on-disk is canonical persistence).
- **Headline recommendations (initial framing — value/cost-balanced):**
  - IW-1 (T-2210): **B — CLI-overlay-only** (highest value/cost 1.30, D dominated)
  - IW-2 (T-2211): **D-rule (classification-by-axis)** — first slice ≈ ~22 tools
  - IW-3 (T-2212): **D — shell-only** opening; A (env-inherit) as pre-approved mate IF MCP leg ships later
  - IW-4 (T-2213): **HM-A + HM-E rider** — MCP-routed agent works T-XXX to work-completed; operator observes /review/T-XXX; JSONL shows no `Bash(bin/fw …)`
  - IW-5 (T-2214): **A — sibling `mcp__framework__*` server** (Shape-2 read-only first slice); federation structurally foreclosed by path-isolation
- **Cross-spike tension flagged:** IW-1 (B = no MCP) is contradicted by IW-4 (HM-A needs MCP) and IW-5 (active sibling-MCP recommendation). Workers ran in isolation.
- **Agent supplemental investigation request:** Operator: *"please also investigate all teh cli erros we have and compare against B vs C"* → filed T-2215 (CLI-error-survey supplemental); first dispatch failed API 529; redispatched.

### 2026-06-05 — Strategic-investment framing pivot
- **Operator directive:** *"ok i thinks this is so fundemental for day-to-day usage of teh framework that high cost are acceptable. its foundational work … and therefor strategic investment, does this make sense?"*
- **Agent response:** Yes — `bin/fw` is empirically the hottest surface (33 existing `--json` sites, 15+ cron callers, every commit hook, every TermLink worker, every consumer project, all Watchtower routes). Producer/consumer parity bugs (L-399 / T-1890) are the exact drift class typed surfaces kill. Foundational claim is grounded.
- **One discipline reframe:** "Foundational, high cost acceptable" ≠ big-bang. §ACD + T-1626/T-1641/T-1670 trio precedent → ship as 3-4 vertically-sliced increments, each demoing the HM-A mechanic at progressively wider scope.
- **Cross-spike tension collapses under new framing:** When cost is not the deciding axis, C (both-as-siblings, BVP 2.97) wins over B; reconfigured IW recommendations integrate cleanly (see §11 below).

### 2026-06-05 — Operator catches orchestrator-routing lens gap
- **Operator directive:** *"can we please check back with the mcp redisgn document and see if we have cuptured all, for instance i am not sure that we have propely adressed teh achetratoir routing lens, amongst others, bnut i might be wrong"*
- **Agent investigation:** No standalone "MCP redesign document" on disk (closest match is this artifact). However, operator was correct — material gaps identified:
  - **Gap #1 (Orchestrator routing lens)** — `orchestrator-mcp-baseline.yaml` (251 classified tools), `agents/audit/orchestrator-mcp-scan.sh`, `lib/resolver.py` dispatch substrate, 5 workflow YAMLs declaring `worker_kind` / `allowed_tools`, route_cache learning. Six concrete sub-questions OR-1..OR-6 (classification entry, scan probe extension, capture coverage, route_cache learning, workflow schema, per-slice procedural debt). NOT addressed in T-2210..T-2214.
  - **Gap #2 (Watchtower frontend migration)** — touched by HM-E but not sized; ~20 blueprints POSTing argv-shape commands need migration.
  - **Gap #3 (Consumer-project propagation)** — `.agentic-framework/bin/fw` ships in every consumer; per-consumer MCP server lifecycle / `.mcp.json` management / `fw upgrade` implications unknown.
  - **Gap #4 (Performance)** — MCP stdio JSON-RPC latency vs shell-exec for high-frequency verbs (cron-fired every 5 min, hooks per tool call).
- **Agent response:** Filed T-2216 (orchestrator-routing-integration spike, OR-1..OR-6) and dispatched TermLink worker. Gap #2, #3, #4 captured as Open Sub-Questions for slice-level resolution (§14 below).
- **Operator directive:** *"proceed as seen fit, prioritize High value / low cost BCP tasks, continue until context is at 300k, apply framework governance"* — initiative delegated.

### 2026-06-05 — T-2215 + T-2216 supplemental spike verdicts return; integrated into §10-§12

- **T-2215 (CLI error survey, B-vs-C empirical lens).** Worker returned 17 KB artifact `docs/reports/T-2215-cli-error-survey.md`. Verdict: *"The empirical CLI-error evidence SUPPORTS B. It does not pivot to C."* Observed CLI pain is dominated by Class P (~15 parse-fragility) + Class O (~7 observability) + half of Class S (~11 type-coupling) — all 100% covered by B's `--json` underlay. C's incremental fixes target MCP clients (a consumer class that currently generates zero errors). On Class A (auth/sovereignty), C is net-negative (adds spoofable §B-005 surface). **Critical build-slice requirement surfaced:** Class S coverage is *conditional* on `--json` shipping a `schema_version` field. A naive shape-dump still lets the ×11 type-coupling class fail silently. **Now folded into Slice 1 ACs (§12).**
- **T-2216 (orchestrator-routing lens, OR-1..OR-6).** Worker returned 24 KB artifact `docs/reports/T-2216-orchestrator-routing-integration.md`. Verdict: *"The orchestrator-routing lens is ~80% absorbed into the existing slice plan as decisions, and adds one bounded build leg — it does NOT spawn a new arc or a new slice."* Slice assignments:
  - OR-1 manifest-declared classification → Slice 2 (trivial emitter)
  - **OR-2 scan probe extension** → **Slice 1 (~40 LoC, the one real build leg)** — without it the framework's own MCP server is invisible to drift defenses, reproducing T-1641-W10 failure one repo over
  - OR-3 capture coverage → DECISION (no, MCP calls not in `dispatches.jsonl`)
  - OR-4 route_cache learning → DECISION (exclude; MCP tools deterministic)
  - OR-5 workflow declaration → DECISION (reuse `allowed_tools`; no `mcp_tools:` field)
  - OR-6 per-slice procedural debt → CONVENTION (introduced by Slice 1, inherited by all)
- **Reconciliation with strategic-investment framing.** T-2215 confirms B suffices for *observed* pain but acknowledges F-ORCH forward bet is a Sovereign operator call — that call was made last session ("foundational work … strategic investment"). T-2216 sharpens C's slice plan without expanding it. Both verdicts coherent with **GO — Path C-scoped (4 slices)**.
- **§10 row added; §12 build-slice shape updated with `schema_version` requirement, OR-2 scan extension, OR-6 verification convention, Slice 2.5 consumer-propagation sub-slice, OR-3/4/5 decisions recorded.**
- **§11 dispositions remain PROPOSED** — operator confirmation still required via Watchtower review of `/inception/T-2209` (Sovereign — cannot lock from `$CLAUDECODE=1`).

*(further entries appended as exploration proceeds)*

---

## §10. Recommendation evolution

| Date | Recommendation | Rationale |
|------|----------------|-----------|
| 2026-06-05 (filing) | DEFER | Five open questions, all needing operator input or read-only spike completion. Honest evidence-gap (not hedge). |
| 2026-06-05 (post-spikes, value/cost framing) | GO — Path B (CLI-overlay-only first; MCP optional later) | IW-1 worker recommendation. Highest value/cost ratio (1.30). 5 IW spikes complete but cross-spike tension between IW-1=B and IW-4/IW-5=needs-MCP-server. |
| 2026-06-05 (strategic-investment framing pivot) | **GO — Path C-scoped (both-as-siblings, sliced)** | Cost no longer the deciding axis. C wins on BVP (2.97 vs 2.86). Cross-spike tension collapses: IW-4 HM-A + IW-5 sibling MCP both presume a server, which C ships. Auth surface stays zero (IW-3 env-inherit + binding conditions). Slice as 3-4 evolutionary increments per §ACD. |
| 2026-06-05 (pending) | TBD — awaits T-2215 + T-2216 + operator confirmation of reconfigured IW dispositions | T-2215 CLI-error survey (slice-1 prioritization data) and T-2216 orchestrator-routing-integration spike (closes Gap #1) both running. Build slicing should wait. |
| 2026-06-05 (post-supplementals) | **GO — Path C-scoped (4 evolutionary slices) — strategic-investment forward bet, empirically grounded** | T-2215 verdict: observed CLI pain is 100% B-addressable; C only justified as forward F-ORCH bet — operator already made that strategic call. T-2216 verdict: orchestrator-routing lens ABSORBED into existing slices; adds only OR-2 scan extension (~40 LoC) to Slice 1, no new arc. Both verdicts coherent. Awaits operator confirmation of §11 dispositions and Sovereign `fw arc create`. |

---

## §11. Reconfigured IW dispositions under strategic-investment framing (PROPOSED — awaits operator confirmation)

| IW | Original (value/cost) | Reconfigured (strategic-investment) | Effective candidate | Status |
|----|----------------------|------------------------------------|---------------------|--------|
| 1 | B (CLI-overlay-only) | **C — both-as-siblings** (`fw --json` underlay + sibling MCP server) | Highest BVP, IW-4+IW-5 alignment | PROPOSED |
| 2 | D-rule, slice 1 ≈ 22 | **D-rule, slice 1 ≈ 22** (foundational framing widens future slices, not slice 1 — keeps §ACD honest) | D-rule yields ~22 | PROPOSED |
| 3 | D (shell-only) | **A — env-inherit** + binding conditions (never strip `$CLAUDECODE`/`AI_AGENT`/`TOOL_NAME`; never expose settings.json verbs) | Required because MCP leg ships in C | PROPOSED |
| 4 | HM-A + HM-E rider | **HM-A + HM-E rider — unchanged** | Was already higher-ambition pick | PROPOSED |
| 5 | A (sibling) | **A — sibling `mcp__framework__*` — unchanged** | Federation foreclosed by path-isolation, never cost-dependent | PROPOSED |

**Sovereignty discipline:** these are *proposed* dispositions surfaced for operator confirmation via `fw task review T-2209`. The agent cannot autonomously bake these into T-2209's `inception_decisions:` text. Operator confirmation drives the lock-in.

---

## §12. Proposed build-slice shape (PROPOSED — awaits T-2216 results + operator)

**Total arc budget:** F8 ≈ 5.4 + 2.7 (OR-2 scan extension, T-2216) ≈ **8.1** (Path C-scoped) — sliced as 4 evolutionary increments per §ACD:

- **Slice 1:** `fw --json` extension to the curated-22 read-only verbs + per-verb `schema_version` field (T-2215 Class-S coverage requirement) + smoke test + OR-2 scan extension to `agents/audit/orchestrator-mcp-scan.sh` so the framework's own MCP server is visible to drift defenses + OR-6 `## Verification` convention introduced. **No MCP server yet** — pure CLI overlay.
- **Slice 2:** Sibling `mcp__framework__*` MCP server skeleton (env-inherit auth + IW-3 binding conditions: never strip `$CLAUDECODE`/`AI_AGENT`/`TOOL_NAME`; never expose settings.json verbs) + `tools/list` returning the 22 read-only tools + HM-F slice-1 read-only smoke test. Adds `orchestrator-mcp-baseline.yaml` entries via T-2216 OR-1 manifest-declared classification.
  - **Slice 2.5 (consumer-propagation, OSQ-B):** dedicated sub-slice — per-consumer `.mcp.json` management, lifecycle (lazy-spawn recommended), `fw upgrade`/`fw vendor` propagation, `tests/unit/upgrade_fresh_machine_simulation.bats` extension per L-417/T-1633.
- **Slice 3:** Adds agent-authority verbs (task_update, work_on, etc.) with `task_id` requirement + HM-A headline mechanic demo (MCP-routed agent picks up T-XXX, works to work-completed via `mcp__fw__*` tools; JSONL shows no `Bash(bin/fw …)`). T-2216 OR-5: reuse `allowed_tools`, no `mcp_tools:` field. Triggers IW-3 auth binding conditions live.
- **Slice 4:** Watchtower frontend migrates one POST endpoint to the new surface (consumer-side validation; HM-E no-shell-out rider proof) — closes Gap #2 / OSQ-A.

Each slice MUST land its own demo (§ACD honest), its own classification baseline diff (per T-2216 OR-6), and its own consumer-fresh-machine bats simulation (per L-417 / T-1633).

**Decisions absorbed (T-2216) — recorded in arc design log, no build:**
- **OR-3:** Do NOT capture MCP calls in `dispatches.jsonl`; per-call audit log optional and deferred.
- **OR-4:** Exclude MCP calls from `route_cache`; MCP tools are deterministic, no model choice.
- **OR-5:** No `mcp_tools:` workflow field; reuse `allowed_tools`; no `worker_kind: mcp`.

---

## §13. Spike status summary

| Spike | Task | Worker | Status | Artifact |
|-------|------|--------|--------|----------|
| IW-1 delivery shape | T-2210 | iw1-delivery-shape | done | docs/reports/T-2210-iw-research.md |
| IW-2 verb scope | T-2211 | iw2-verb-scope | done | docs/reports/T-2211-iw-research.md |
| IW-3 auth model | T-2212 | iw3-auth-model | done | docs/reports/T-2212-iw-research.md |
| IW-4 headline mechanic | T-2213 | iw4-headline-mechanic | done | docs/reports/T-2213-iw-research.md |
| IW-5 overlap | T-2214 | iw5-overlap | done | docs/reports/T-2214-iw-research.md |
| Supplemental: CLI error survey | T-2215 | iw1-cli-error-survey-retry | **done** (2026-06-05 17:07Z) | docs/reports/T-2215-cli-error-survey.md — *Verdict: B suffices for observed pain; C requires strategic forward-bet (operator's call, already made)* |
| Supplemental: orchestrator routing | T-2216 | iw-or-routing | **done** (2026-06-05 17:07Z) | docs/reports/T-2216-orchestrator-routing-integration.md — *Verdict: ABSORBED; +1 build leg (OR-2 scan extension) in Slice 1; OR-3/4/5 are decisions; OR-6 process convention* |

---

## §14. Open Sub-Questions captured for slice-level resolution

Gaps #2, #3, #4 are not arc-shape questions — they are slice-build questions. Captured here for honest deferral:

- **OSQ-A (Gap #2 — Watchtower migration).** How does `web/blueprints/*.py` migrate from argv-shape POST to JSON-shape requests? Approx 20 blueprints. **Slice assignment:** Slice 4 (HM-E consumer demo); concrete blueprint-by-blueprint migration plan filed at slice-4 design time. Pre-condition: at least one HM-A demo from Slice 3 has shipped to validate the typed-call shape.
- **OSQ-B (Gap #3 — Consumer-project propagation).** Does each consumer project run its own `mcp__framework__*` server? How is `.mcp.json` managed per-consumer? Lifecycle (autostart? systemd? lazy-spawn?). `fw upgrade` / `fw vendor` propagation implications. **Slice assignment:** Slice 2.5 — a dedicated "consumer-propagation" sub-slice between Slice 2 (skeleton) and Slice 3 (agent-authority verbs). Must include `tests/unit/upgrade_fresh_machine_simulation.bats` extension (per L-417 / T-1633 discipline).
- **OSQ-C (Gap #4 — Performance).** MCP stdio JSON-RPC latency vs shell-exec for high-frequency verbs (e.g. `fw context status` called by cron every 5 min, hooks firing on every tool call). **Slice assignment:** Slice 1 includes a latency benchmark for the curated-22 read-only set. If any verb is >2× shell-exec slower under JSON output mode, that verb either gets a fast-path or stays shell-only. Decision criterion is empirical, not architectural.
- **OSQ-D (Cross-spike consistency).** The 5 IW workers ran in isolation and produced one cross-spike contradiction (resolved by operator framing pivot). For future multi-IW inception dispatch patterns, consider adding a **synthesis spike** that reads all sibling artifacts and produces a coherence-check before operator presentation. Captured as candidate for the dispatch-pattern template at `docs/dispatch-templates/iw-spike-worker.md`.

### Newly-surfaced OSQs (from T-2216, captured for slice-level resolution):
- **OSQ-E (MCP manifest format).** Format/location of `framework-mcp-manifest.json` depends on Slice 2's language choice (Python vs other). Finalised at Slice 2 design time.
- **OSQ-F (Per-call audit log).** Should the framework MCP server emit a per-call audit log (request IDs, idempotency keys from HM-A)? Overlaps with IW-4 HM-A and T-2215 CLI error lens — optional micro-build, deferred. Becomes MANDATORY if sovereignty-bound verbs are ever MCP-exposed (currently §3-foreclosed).
- **OSQ-G (Baseline file count).** One baseline file or two? T-2216 assumes one `orchestrator-mcp-baseline.yaml` holding both `termlink_*` and `mcp__framework__*` (prefixes don't collide). Operator may prefer split — cosmetic call, not structural.
- **OSQ-H (Cross-repo convention propagation).** The `mcp__framework__*` manifest pattern is strictly better than termlink's grep-over-Rust probe. Worth a cross-link to termlink baseline owners as a forward proposal (out of scope — path isolation; propose via TermLink U-message, do not edit).
| *(future)* | *(GO / NO-GO / refined DEFER)* | *(updated after Spikes 1-5 land in §3-§7 and operator returns disposition on IW-1..IW-4)* |
