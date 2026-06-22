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

> *TermLink's MCP has hundreds of `mcp__termlink__*` tools in daily use. AEF's has 22 unused. Why the
> difference?* Code-read of `/opt/termlink` in progress; agent contact filed on thread `aef-mcp-adoption`
> (note: local termlink session shares this host's identity fingerprint, so the DM is a self-loop — the
> code is the reliable source).

_[TO FILL from the /opt/termlink code-read: (1) server architecture + tool-registration mechanism;
(2) codegen-from-CLI vs hand-maintained; (3) how the server gets auto-wired into `.mcp.json` — their
answer to our RC-1; (4) discoverability/adoption design; (5) transferable vs non-transferable lessons
given TermLink is intentionally machine-wide and AEF is intentionally per-project-isolated.]_

## 5. Recommendation

**GO.** Pursue adoption. The gap is real, evidenced, and is the arc-010 deliverable that never landed.
Consumer-wiring (slice 1) is unambiguously correct and high-leverage — file it as the first build child
regardless of the strategy choice. The strategy fork (§3) is the operator's call and gates only the
docs/coverage scope (slices 3+).

## 6. Dialogue log

### 2026-06-22 — operator ask
- **Operator:** "we have done a lot of work on putting the cli functionality in mcp but i still dont see
  us and other aef project using the aef mcp." Then: "a [file the inception + tee up consumer-wiring],
  also contact termlink, for termlink we have implemented MCP check how they did that and what we can
  learn from that."
- **Response:** investigated (Explore sweep) → 3 root causes; reframed as arc-010 headline-mechanic gap;
  filed this inception (GO, strategy fork for human); dispatched a /opt/termlink code-read + contacted the
  termlink agent thread. Consumer-wiring teed up as slice 1.
