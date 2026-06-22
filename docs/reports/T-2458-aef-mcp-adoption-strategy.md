# T-2458 — AEF fw-MCP Adoption Strategy

**Inception.** One question: *Why is the AEF `fw` MCP server not used (by our own sessions or
by other AEF projects), and what is the strategy + minimal slice to drive adoption?*

Status: research artifact (C-001). Recommendation: **GO** (pursue adoption; consumer-wiring is
slice 1 regardless of strategy). Human picks strategy 1/2/3 via the inception decision.

---

## 1. Problem statement

We invested in exposing `fw` CLI functionality through an MCP server (`agents/mcp/framework_mcp_server.py`,
stdio, shells to `bin/fw`; 22 curated tools in `policy/capability-overlay/tool-set.yaml`). Yet:

- **Our own agents don't use it.** This very session made ~30 `fw` calls via Bash/TermLink and **0**
  `mcp__fw__*` calls. Exhibit A.
- **Other AEF (consumer) projects can't use it** — they never receive the server in their `.mcp.json`.

This is **arc-010's headline-mechanic gap** in textbook form: the arc shipped the *substrate* (server,
22 tools, manifest, drift gate) but never landed the *deliverable* — an agent observably using the MCP
to do real work. "The server is built and in sync" is the "substrate is in place" §ACD framing the
framework explicitly warns against (G-062).

## 2. Root causes (evidence)

### RC-1 — Consumers never receive the server (CRITICAL, infrastructure)
- `lib/init.sh:822-845` — the `.mcp.json` template ships only `context7`, `playwright`, `termlink`. No `fw`.
- `lib/upgrade.sh:1462` — `recommended_servers='{"context7":1,"playwright":1,"termlink":1}'`; `fw` is never
  added or synced into consumer `.mcp.json`.
- Git: `6ef1c1816` (T-2268) added `fw` to the *framework's own* `.mcp.json` but touched neither init nor
  upgrade. The propagation step was never built. A consumer's vendored `.agentic-framework/` *contains*
  the server code, but its `.mcp.json` never points at it.

### RC-2 — Nothing steers anyone to it (cultural / docs)
- `CLAUDE.md`: **zero** `mcp__fw__*` references. Every example across ~1000 lines is `bin/fw …`. The only
  "MCP" mentions are about *maintaining* it (`fw mcp emit-manifest`, the manifest-drift gate) — never about
  *using* it. The docs treat the fw MCP as an artifact to keep in sync, not the agent's interface.
- The `mcp__fw__*` tools are **deferred** in Claude Code — schemas aren't loaded; an agent must `ToolSearch`
  to even call them, while `Bash` is always present. Path of least resistance is always the shell.

### RC-3 — Even when wired, it hangs in workers (operational)
- OBS-058/059/060/061 (`.context/inbox.yaml`): framework-mcp stays `pending` indefinitely in dispatched
  `claude -p` workers — needs `--permission-mode acceptEdits` (partly done, T-2282) plus per-project
  `permissions.allow` trust entries. T-2268 ACs #4-7 remain blocked on operator triage.

### Secondary — coverage subset
- 22 MCP tools (16 read-only + 6 agent-authority) vs ~60 `fw` subcommands. Curated by design
  (sovereignty verbs intentionally excluded). But a subset means agents fall back to shell for the long
  tail — which, absent an MCP-first rule, means they shell for *everything*.

### Gate interaction (a lever, not a blocker)
- `.claude/settings.json` PreToolUse matchers are `Bash|Write|Edit` / `Bash` / `TodoWrite|…` — **none match
  `mcp__fw__*`**. So an `mcp__fw__work_on` call **bypasses the worktree Bash gate (OBS-080)** that blocked
  shell `fw` all session, then re-applies gates by shelling to `bin/fw` *inside* the server. In worktree
  sessions the MCP is therefore the *strictly better* path — a concrete adoption argument.

## 3. The strategic fork (the inception question)

The coverage/docs direction depends on a decision only the operator can make:

1. **MCP-first for the common path** — declare `mcp__fw__*` the primary interface for task-lifecycle +
   observability; shell only for the long tail. Highest adoption; creates a two-path world.
2. **MCP for specific contexts only** — keep shell primary; use MCP where strictly better: consumer /
   cross-project sessions, sandboxed/permission-gated runs, and worktree sessions (gate-bypass). Targeted;
   lower uptake.
3. **Invest to make it the real interface** — expand toward CLI parity, register tools so they're not
   deferred, rewrite CLAUDE.md MCP-first. Biggest spend; "do it properly."

**Correct under all three** (so not blocked on the fork):
- **Slice 1 — wire consumers** (init + upgrade add the `fw` server). Highest leverage; without it "other
  AEF projects" cannot begin.
- **Slice 2 — resolve the worker-hang** (OBS-058/061, T-2268 ACs 4-7).

## 4. What TermLink teaches (benchmark — theirs is adopted)

TermLink's MCP is adopted because of **three design choices AEF made the opposite of**. (Contact
filed on thread `aef-mcp-adoption` — but the local termlink session shares this host's identity
fingerprint, so that DM is a self-loop; findings below are from the code-read, the reliable source.)

| Dimension | TermLink (adopted) | AEF fw-MCP (not adopted) |
|-----------|--------------------|--------------------------|
| **Wiring** | Pre-wired in the `.mcp.json` template `fw init`/`upgrade` ships (`{"command":"termlink","args":["mcp","serve"]}`) — every consumer gets it automatically | `fw` server in the framework's *own* `.mcp.json` only; consumer template (`lib/init.sh:822`, `lib/upgrade.sh:1462`) omits it → **RC-1** |
| **Server** | Built-in subcommand `termlink mcp serve` (single machine-wide binary) | Separate per-project python script `agents/mcp/framework_mcp_server.py` |
| **Tool catalogue** | ~220 tools auto-discovered + convention-classified by verb-suffix (`*_list/_status` → read; `_post/_send/work_on` → mutator); self-healing baseline, **zero manual maintenance** (`agents/audit/orchestrator-mcp-scan.sh:162-210`, 196 tools / 7 batches / 0 misclassifications) | 22 hand-curated entries in `tool-set.yaml`; adding a verb = manual YAML edit. Agents fall back to shell for the long tail |
| **Discoverability** | `termlink_<ns>_<verb>` naming; CLAUDE.md teaches the tools + `task_id` governance | `mcp__fw__*`, deferred; CLAUDE.md never mentions them → **RC-2** |

**Transferable to AEF (adapted for the per-project model):**
1. **Auto-wire the `fw` server into the consumer `.mcp.json` template** (init + upgrade). This is the
   single thing that makes TermLink universal — and it's exactly our slice 1. Confirmed as THE fix.
2. **Codegen the tool catalogue from `fw help` + convention-classify** instead of hand-curating
   `tool-set.yaml`. AEF already has the drift-scan substrate — `orchestrator-mcp-scan.sh` has a
   *framework-mcp leg* (~lines 398-448) that probes the fw MCP. Extending it to auto-classify by
   verb-suffix would remove the maintenance tax and let coverage grow toward parity cheaply.
3. **Document in CLAUDE.md** (MCP guidance + `task_id`) — TermLink's tools are used partly because
   the docs teach them; ours are invisible.

**NOT transferable:** TermLink is *intentionally machine-wide* (single binary on PATH — its session
discovery needs system sockets); AEF is *intentionally per-project-vendored/isolated*. So we copy the
*auto-wire-into-`.mcp.json`* and *convention-codegen* patterns, **not** the machine-wide install model.

**Strategy implication:** the codegen insight materially lowers the cost of Strategy 3 (full parity).
If new `fw` verbs auto-expose via convention-classification, "near-complete mirror" stops being an
expensive hand-maintenance burden and becomes nearly free — which makes Strategy 1 (MCP-first) and
Strategy 3 more attractive than a pure-curation reading would suggest. The operator's strategy call
(IW-1) should weigh this: parity-via-codegen is the path that made TermLink's MCP the default surface.

## 5. Recommendation

**GO.** Pursue adoption.

**Operator-chosen direction (2026-06-22 chat):** the full "make the MCP the real interface" path —
(A) MCP as the default path, (B) CLI commands auto-added to the MCP, (C) auto-propagation via
`fw init`/`upgrade`. This resolves IW-1 toward Strategy 3, fed by auto-codegen (B) and propagated by
upgrade (C). The TermLink benchmark validates this is the path that produced their adoption.

### Sequenced slices (C → B → A — availability, then coverage, then default)

- **Slice 1 (C) — auto-propagate** (`fw init`/`upgrade` wire the `fw` server into consumer
  `.mcp.json`). Foundational + safe + testable (`upgrade_fresh_machine_simulation.bats`). Do first —
  nothing else matters if consumers don't have the server.
- **Slice 2 (B) — auto-codegen** the MCP catalogue from the `fw` command registry / `fw help` +
  convention-classify (verb-suffix: `*-list/-show/-status` → read; `work-on/task-update` →
  agent-authority). Replaces manual `tool-set.yaml` curation. Extend the existing
  `orchestrator-mcp-scan.sh` framework-mcp leg for drift/auto-class.
- **Slice 3 (A) — make it default** — CLAUDE.md MCP-first guidance + `task_id` docs; ensure the
  tools surface without per-call ToolSearch friction (registration/preload).

### Two hard design constraints (NEW — scope-affecting)

1. **Gate-matcher parity (governance hole if missed).** The PreToolUse hooks
   (`check-active-task`, `budget-gate`, `check-tier0`, `block-task-tools`) match `Bash|Write|Edit`
   only — **none match `mcp__fw__*`**. Today that's harmless (nobody uses the MCP). But the moment
   the MCP becomes the *default path* (A), agents routing through `mcp__fw__*` would **bypass the task
   gate, budget gate, and tier-0 gate**. So slice A/B MUST extend the hook matchers to cover the
   `mcp__fw__*` tools (or move the equivalent checks server-side in `framework_mcp_server.py`).
   Making MCP default *without* this would weaken governance, not strengthen it. This is L-399
   producer/consumer parity applied to the gate layer.
2. **Sovereignty denylist is a HARD gate in the codegen (B).** Auto-discovery must never expose the
   sovereignty verbs (`inception_decide`, `tier0_approve`, `arc_close`, `bvp_confirm`,
   `enforcement_baseline`). TermLink's convention-classifier had zero misclassifications, but for AEF
   a single false-positive that exposed `tier0_approve` to an agent is a sovereignty breach, not a
   cosmetic bug. The codegen needs the exclusion list as an explicit denylist + a regression test that
   asserts no sovereignty verb ever appears in the emitted manifest.

## 6. Dialogue log

### 2026-06-22 — operator ask
- **Operator:** "we have done a lot of work on putting the cli functionality in mcp but i still dont see
  us and other aef project using the aef mcp." Then: "a [file the inception + tee up consumer-wiring],
  also contact termlink, for termlink we have implemented MCP check how they did that and what we can
  learn from that."
- **Response:** investigated (Explore sweep) → 3 root causes; reframed as arc-010 headline-mechanic gap;
  filed this inception (GO, strategy fork for human); dispatched a /opt/termlink code-read + contacted the
  termlink agent thread. Consumer-wiring teed up as slice 1.

### 2026-06-22 — operator resolves the strategy
- **Operator:** "not sure what the choices are but i know that: A: i want mcp to be the default path;
  B: i want cli commands to be auto added to the mcp; C: i want it to propagate automatically via
  upgrades etc."
- **Outcome:** IW-1 resolved → the full "make MCP the real interface" path (Strategy 3). A=default path,
  B=auto-codegen catalogue, C=auto-propagate via init/upgrade. Sequenced C→B→A (see §5). Two hard
  constraints surfaced: gate-matcher parity for `mcp__fw__*`, and a sovereignty denylist in the codegen.
  Formal GO recorded by operator at `/inception/T-2458` (agent cannot self-decide — sovereign).
