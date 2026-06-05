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

*(further entries to be appended as exploration proceeds and operator feedback lands)*

---

## §10. Recommendation evolution

| Date | Recommendation | Rationale |
|------|----------------|-----------|
| 2026-06-05 (filing) | DEFER | Five open questions, all needing operator input or read-only spike completion. Honest evidence-gap (not hedge). |
| *(future)* | *(GO / NO-GO / refined DEFER)* | *(updated after Spikes 1-5 land in §3-§7 and operator returns disposition on IW-1..IW-4)* |
