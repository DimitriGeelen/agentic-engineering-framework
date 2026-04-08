# T-1061: TermLink as Deterministic Governance Substrate

## Research Origin

Dialogue between Dimitri and Claude (external session, 2026-04-07). Enhanced with evidence from 880+ completed tasks, 15 enforcement hooks, 11 tracked concerns, and 2557 traced commits across the Agentic Engineering Framework. **Reviewed and corrected** by Claude Code session running inside the TermLink project (`/opt/termlink`) with full access to TermLink's context fabric, component cards, and codebase — citing specific code paths.

## Core Thesis

TermLink provides **deterministic governance** of the prime directive ("nothing gets done without a task") through its **MCP tool interface, hub orchestrator, and data plane** — not through PTY byte stream parsing. Claude Code hooks provide only **stochastic enforcement** that is bypassable. This is not speculation — the framework has 8 months of evidence documenting exactly where application-layer hooks fail, and the TermLink project has confirmed which governance mechanisms are architecturally sound versus which are infeasible.

## The Problem: Application-Layer Enforcement Has Known Holes

The Agentic Engineering Framework currently enforces governance through **15 Claude Code hooks** across 4 event types:

| Event | Hooks | Purpose |
|-------|-------|---------|
| PreToolUse | 6 | Task gate, Tier 0 block, budget gate, project boundary, plan mode block, agent dispatch |
| PostToolUse | 6 | Checkpoint, error watchdog, dispatch size, loop detect, fabric registration, commit cadence |
| PreCompact | 1 | Auto-handover before context compression |
| SessionStart | 2 | Post-compact recovery |

**These hooks are the most sophisticated governance layer any AI agent framework has.** And they have documented, structural limitations:

### Known Gaps in Hook-Based Enforcement (from concerns.yaml)

**G-011: PostToolUse hooks are advisory-only.** Claude Code PostToolUse hooks always exit 0. `error-watchdog.sh` and `check-dispatch.sh` can warn but cannot prevent the agent from ignoring errors or dispatching too many agents. The agent can — and does — ignore PostToolUse warnings. This is not a bug; it's a design constraint of the Claude Code hook API.

**G-015: Sub-agent results bypass task governance.** Sub-agents dispatched via Claude Code's Task tool write results to `/tmp/fw-agent-*.md` (outside PROJECT_ROOT). These writes bypass `check-active-task.sh` and are never registered against the active task. The task gate enforces at Write/Edit — but sub-agents operate in a parallel context where the gate doesn't exist.

**G-017: Execution gates do not cover the proposal/suggestion layer.** The framework can block an agent from *writing* code without a task, but cannot prevent it from *suggesting* or *planning* ungoverned work. The hook fires on tool use, not on reasoning.

### Failure Pattern Evidence

**FP-011 (T-576):** `fw termlink dispatch` silently fails inside Claude Code because the `CLAUDECODE` env var blocks `claude -p` subprocess spawning. The workaround (`unset CLAUDECODE`) is itself fragile — it depends on knowing which env vars the vendor sets. Application-layer integration is a moving target.

**T-061 (founding incident):** Third-party plugins acted as a "second agent" and bypassed task creation entirely. 0/20 loaded skills were task-aware. The investigation required 4 parallel analysis agents to diagnose. Root cause: skills don't know about the framework's governance model. The hooks were added *in response* to this incident — they're patches on a fundamentally leaky layer.

**T-577 (orphan processes):** `termlink run --timeout` deregisters the session but doesn't kill the process. A `claude -p` agent wrote output **65 minutes after** a 900-second timeout. The process was invisible to TermLink, invisible to the framework, still consuming resources. Fixed with a kill watchdog in `fw termlink dispatch`, but the root cause is: session deregistration != process governance.

## The Architectural Insight

The framework has spent 8 months building increasingly sophisticated application-layer enforcement. The result is impressive (98% commit traceability, 4-tier enforcement, 15 hooks), but the architecture has a structural ceiling:

**Hooks react to tool calls. They cannot govern the agent itself.**

- PreToolUse fires *after* Claude Code decides to act, *before* execution — but the agent already consumed context reasoning about the action
- PostToolUse fires *after* execution — it can log, but it cannot undo
- No hook fires on *thinking*, *planning*, or *reasoning* — the most expensive context operations
- Sub-agents inherit zero governance from the parent session
- `--no-verify` on git, `--force` on task completion — bypass paths exist because the substrate allows them

**The right solution is governance at TermLink's structured interfaces — MCP tools, RPC methods, and hub orchestrator — not at the PTY byte stream level.** The agent operates *through* these interfaces. Governance checks at this layer are structured, reliable, and blockable.

## What the TermLink Project Review Corrected

The initial version of this document proposed PTY byte stream parsing as the governance mechanism. The TermLink project review (conducted by Claude Code with full access to TermLink's context fabric and component cards) identified five fundamental corrections:

### Correction 1: TermLink Does NOT Parse the PTY Byte Stream

The PTY read loop (`pty.rs:171-219`) is fire-and-forget. The **only** pattern matching on the stream is scanning for 9-byte alternate screen escape sequences (`\x1b[?1049h` / `\x1b[?1049l`) in `pty.rs:350-371`. No tool call detection. No "Running bash..." parsing. No structured signal extraction.

Claude Code's terminal output is ANSI-formatted, color-coded, cursor-positioned rendered text — not structured data. Parsing "Running bash..." from a stream interleaved with SGR codes (`\x1b[38;5;214m`), OSC sequences, cursor movements, and partial multi-byte reads is fundamentally harder than reading structured JSONL. It would require building half a terminal emulator — precisely the trap the document warned against.

### Correction 2: "Buffer/Pause the Stream" Does Not Exist

The scrollback buffer (`scrollback.rs`) is a `VecDeque<u8>` ring buffer with FIFO eviction. No pause/resume API. The broadcast channel uses `tx.send()` which never blocks the sender. To "hold the buffer," you'd have to stop calling `libc::read()` on the master FD, filling the kernel's ~4KB PTY buffer, eventually blocking the child's `write()` syscalls. This isn't governance — it's a deadlock. There's no way to "hold, check, release" atomically.

### Correction 3: Sub-Agent Governance Is Not Solved by Hub Visibility

G-015 is about Claude Code's `Task` tool creating **in-process sub-agents** (threads inside the Claude Code process), not separate terminal sessions. They don't register with any hub. They don't create PTY sessions. They write to the filesystem via `write()` syscalls that bypass the PTY entirely. PTY ownership gives you the byte stream, not the process's syscalls. Governing those would require syscall interception (seccomp, ptrace) or filesystem-level enforcement (FUSE) — none of which are in TermLink's scope.

### Correction 4: Multi-LLM Routing Conflates Two Problems

The existing `orchestrator.route` (`router.rs:640-1000+`) routes **RPC methods to specialist sessions** based on tags/roles/capabilities — not models. Model routing would require managing multiple agent processes per model and directing work to the right one. The dispatch system has spawn/collect primitives but not the intelligence layer. This is achievable (2-3 months), but it's a new capability, not an extension of existing routing.

### Correction 5: The Kernel Analogy Was Misapplied

The kernel enforces memory protection not by parsing the byte stream of program output, but by **controlling the syscall interface**. TermLink's "syscall interface" is MCP + RPC, not the PTY byte stream. Govern there.

## The Three Governance Layers

After the TermLink project review, the correct architectural picture has three layers:

| Layer | Mechanism | Enforcement Model | What It Governs |
|-------|-----------|-------------------|-----------------|
| **MCP Tools** | TermLink MCP server (4378 lines, 40+ tools) loaded INTO Claude Code | Structured JSON, reliable, blockable | Cross-session operations via TermLink |
| **Hub Orchestrator** | `orchestrator.route` chain + bypass registry + circuit breaker | Deterministic RPC routing with learning | Inter-session routing, failover, promotion |
| **Data Plane** | Binary frame protocol (8 frame types, 22-byte headers) | High-throughput streaming | Real-time output, file transfer, governance frames (future) |

### Layer 1: MCP as Governance Interface

TermLink's MCP server is loaded INTO Claude Code. Every `termlink_exec`, `termlink_inject`, `termlink_interact` call goes through TermLink's code. Governance checks can be added at MCP tool level:

- Before executing `termlink_exec`, check if a task exists
- Before `termlink_spawn`, validate against task scope
- Before `termlink_dispatch`, enforce concurrency limits

This is structured (JSON parameters), reliable (MCP protocol), and doesn't require parsing terminal output. The limitation: it only governs operations that go through TermLink MCP tools — not Claude Code's native Write/Edit/Bash. But for cross-session orchestration governance, MCP IS the interface.

### Layer 2: Hub Orchestrator (Already Exists)

The document initially overlooked that TermLink already has governance primitives at the RPC layer:

- **Bypass registry** (`bypass.rs`): Commands promoted to Tier 3 after `PROMOTION_THRESHOLD` (5) successful orchestrated runs. Denylist patterns prevent dangerous commands from ever being promoted. Failed bypass executions de-promote. This IS deterministic governance.
- **Route cache** (`route_cache.rs`): Caches method -> specialist mappings with confidence scores and hit counts. Stale entries expire. Failed cached routes fall through to full discovery.
- **Circuit breaker** (`circuit_breaker.rs`): Per-session, opens after 3 consecutive transport failures, 60-second cooldown, half-open probing. Prevents routing to dead specialists.

The full orchestrator route chain:
```
orchestrator.route request
  -> bypass registry check (Tier 3 shortcut)
  -> route cache check (learned specialist routing)
  -> session.discover (find matching specialists)
  -> forward + failover (with circuit breaker)
  -> success/failure tracking (bypass promotion, cache update)
```

This is already deterministic, already at the hub level, already provides failover, learning (bypass promotion after 5 successes), and protection (circuit breaker, denylist).

### Layer 3: Data Plane (Future Governance Extension)

The binary frame protocol (`data.rs`) has frame types including Signal (0x3). A governance-aware data plane subscriber could: receive Output frames -> parse for patterns -> emit Governance frames back to the session -> session handler blocks/allows based on governance frame. This preserves the existing architecture while adding an interception point — but it remains post-hoc, not blocking, and should not be confused with "deterministic" enforcement.

## Key Comparison: Three-Layer Governance

| Property | TermLink MCP + Hub | Claude Code Hooks | PTY Parsing (rejected) |
|----------|-------------------|-------------------|----------------------|
| Enforcement model | Structured API — blockable | Callback — bypassable | Heuristic — unreliable |
| Bypass possible | No — tool code runs governance | Yes — `--no-verify`, API changes | N/A — parsing fails silently |
| Substrate stability | MCP protocol (standard) | Claude Code API (changes per sprint) | ANSI output (changes per release) |
| What it governs | Cross-session operations | Native tool calls | Nothing reliably |
| Agent-agnostic | Yes — any MCP client | No — Claude Code specific | Coupled to output format |
| Failure mode | Structured error (JSON) | Silent (G-011: advisory PostToolUse) | False positives/negatives |
| Implementation effort | Weeks (MCP hooks exist) | Done (15 hooks) | Months (terminal parser) |

## Architecture: TermLink Through the Four Constitutional Directives

### 1. Antifragility — System strengthens under stress

**Current state:** The framework's healing loop (diagnose -> classify -> suggest -> resolve) feeds `patterns.yaml` and `learnings.yaml`. But the loop depends on the agent *choosing* to invoke it. When the agent crashes, ignores an error (G-011), or runs out of context, the learning event is lost.

**With MCP + Hub governance:**
- **Bypass registry as antifragile learning:** Commands that succeed 5 times get promoted to Tier 3 (fast path). Commands that fail get de-promoted. The system literally learns which operations are safe from experience — the definition of antifragility.
- **Circuit breaker protects against cascading failure:** Per-session circuit breaker opens after 3 consecutive transport failures. The system degrades gracefully, not catastrophically.
- **Session continuity across crashes:** TermLink sessions persist across process restarts (T-179 auto-restart already leverages this). Task context survives terminal crashes because it lives in the hub, not in the agent's context window.
- **Evidence:** T-577 showed that timeout != governance. PTY ownership means: if TermLink can't see the process, the process can't act. The kill watchdog in `fw termlink dispatch` enforces this at process level.

### 2. Reliability — Predictable, observable, auditable execution

**Current state:** 15 hooks provide strong enforcement but with documented holes. PreToolUse can block Write/Edit/Bash. PostToolUse can warn but not block (G-011). Budget gate reads JSONL transcripts for token counting but depends on file availability.

**With MCP + Hub governance:**
- **MCP-level enforcement is structural:** When `termlink_exec` checks for a task before executing, there is no advisory-only gap. The MCP tool either proceeds or returns an error. G-011 ceases to exist at this layer.
- **Complete audit trail via hub:** Every RPC method, every event, every route decision passes through the hub. The orchestrator chain already tracks success/failure for bypass promotion — extending to full audit is natural.
- **Dual-channel architecture ensures separation:** Control plane (JSON-RPC 2.0, structured, moderate latency) for governance decisions. Data plane (binary frames, high-throughput, low-latency) for streaming. Governance decisions don't compete with data throughput.
- **Caveat on G-015:** Sub-agent governance (in-process threads writing to `/tmp/`) remains unsolved at the TermLink layer. This requires Claude Code-level changes or filesystem enforcement — outside TermLink's architectural scope.

### 3. Usability — Joy to use/extend/debug

**Current state:** The Watchtower web UI provides visibility into tasks, timeline, costs, fabric, and more (34+ endpoints). But operational experience — what's happening right now across active agents — requires terminal switching.

**With task-aware terminal chrome:**
- **WezTerm + TermLink RPC:** Session metadata (tags, roles, status, KV store) is already available via RPC. A WezTerm Lua plugin querying `termlink list --json` and `termlink status` can display task state in terminal chrome — zero new TermLink code needed.
- **Multi-pane task governance UI:** No orphan terminals. Every pane owned by a task with visible state.
- **Context fabric visualization:** What knowledge is loaded for this task, displayed alongside agent output.
- **Dispatch system as multi-agent UX:** `termlink dispatch` already provides atomic spawn, worktree isolation, result collection via events. Extending with task-awareness (each worker gets task assignment, reports via events) is 2-4 weeks.

### 4. Portability — No provider/language/environment lock-in

**Current state:** Enforcement is 100% Claude Code specific — `.claude/settings.json` hooks, Claude Code's PreToolUse/PostToolUse API. If the user switches to Cursor, Windsurf, or a future agent, all 15 hooks stop working.

**With MCP + Hub governance:**
- **Agent-agnostic via MCP standard:** Any MCP-capable agent can use TermLink's 40+ tools. Governance checks in MCP tools work regardless of which agent calls them.
- **Substrate stability:** MCP protocol is a standard. TermLink's RPC is JSON-RPC 2.0 (decades old). Neither changes when Claude Code updates. FP-011 (CLAUDECODE env var breaking dispatch) is a concrete example of vendor-specific fragility.
- **Multi-LLM routing as portability:** Hub-level specialist routing means switching providers is configuration, not architecture. The dispatch system can spawn workers with different model configs.
- **Standards-based stack:** PTY protocol, JSON-RPC control plane, MCP tool interface, HMAC security — no proprietary lock-in at any layer.

## Execution Features

### Multi-LLM Routing (Usability + Portability)

**Current state:** Model selection is per-session (`claude --model sonnet`). No task-aware routing.

**Proposed (corrected):**
- Extend `orchestrator.route` with task-type-based routing and model-aware specialist selection
- Dispatch system spawns workers with specific model configs: `fw termlink dispatch --model haiku --prompt "..."` 
- Route cache learns which models succeed for which task types (bypass promotion pattern)
- Circuit breaker provides automatic fallback when a model is unavailable
- **Timeline:** 2-3 months — new capability building on existing orchestrator primitives
- **Evidence for value:** Current session: 2.8B cached tokens, 3.1M output tokens. Routing routine tasks to Haiku could reduce costs 60-80%.

### Monitor/Management Surface (Reliability + Usability)

**Current state:** `termlink list`, `termlink pty output`, Watchtower `/sessions` — no real-time cross-agent dashboard.

**Proposed:**
- Real-time view across all active tasks and their agents
- Pause, redirect, or kill a specific agent without killing others
- Session lifecycle metrics, event throughput, RPC latency already available at hub level
- **WezTerm plugin is the natural UI** — queries TermLink RPC, no new TermLink code needed, 3-6 weeks

### Metadata Collection (Antifragility + Reliability)

**Current state:** Session metrics track cumulative stats. Token costs tracked via `fw costs`. After-the-fact analysis only.

**Proposed (corrected feasibility):**
- **Easy (existing):** Session lifecycle metrics, event throughput, RPC latency, route cache statistics, circuit breaker states — all available now at hub level
- **Hard (requires new parsing):** Per-tool failure rates, model token usage, tool call counts — all require parsing tool calls from either JSONL transcripts or PTY output. No shortcut exists.
- **Recommended approach:** Instrument MCP tools for the cross-session operations TermLink handles. For native Claude Code operations (Write/Edit/Bash), continue using JSONL transcript analysis (the current approach works, it's just after-the-fact).

## Terminal Chrome Evaluation

### Why Not Build a Terminal Emulator
- VT100/ANSI/xterm compatibility alone is months of undifferentiated engineering
- TermLink's value is in the governance primitives, not in rendering text

### Middle Ground: WezTerm Plugin (Recommended)
A Lua plugin that adds task-aware UX by querying existing TermLink APIs:
- Task state in terminal chrome (tags, roles, status from session metadata)
- Multi-pane task governance UI without depending on tmux/screen
- Session history with task-level drill-down
- **Zero new TermLink code required** — reads from existing RPC endpoints
- **Timeline:** 3-6 weeks

### Zellij Alternative
- WASM plugin system — architecturally cleaner for isolation
- Task governance as a WASM plugin
- But Zellij is a multiplexer, not an emulator — still depends on underlying terminal
- Evaluate if WezTerm's Lua API proves insufficient

**Recommendation:** WezTerm for immediate value. Zellij's WASM plugin system for cleaner long-term architecture.

## Feasibility Assessment (from TermLink Project Review)

| Capability | Rating | Timeline | Rationale |
|------------|--------|----------|-----------|
| Task-aware terminal chrome | **Medium** | 3-6 weeks | Session metadata already available via RPC. WezTerm Lua plugin is straightforward. |
| MCP-level governance | **Medium** | 2-4 weeks | Add task-gate checks to existing MCP tools. Structured, reliable. |
| Extend orchestrator routing | **Medium** | 2-4 weeks | Natural evolution of existing `orchestrator.route` chain. |
| Multi-LLM routing | **Hard** | 2-3 months | New capability: multiple agent processes per model, task classification logic, result aggregation. |
| Data plane governance subscriber | **Medium** | 4-8 weeks | Post-hoc pattern detection on Output frames. Not blocking, useful for audit/metrics. |
| PTY tool call parsing | **Hard** | 2-4 months | Requires terminal output parser. Patterns change per release. Heuristic, not deterministic. |
| Pre-hook via PTY buffer hold | **Rejected** | Never | Architecture doesn't support it safely. Deadlock risk. MCP governance is strictly superior. |

## Implementation Path (Corrected)

1. **Phase 1 (now, 3-6 weeks):** Task-aware terminal chrome via WezTerm plugin querying existing TermLink RPC APIs. Zero new TermLink code.

2. **Phase 2 (weeks, 2-4 weeks):** MCP-level governance — add task-gate checks to TermLink MCP tools so cross-session operations are governed. Structured, reliable, blockable.

3. **Phase 3 (weeks, 2-4 weeks):** Extend `orchestrator.route` with task-type-based routing and model-aware specialist selection. Natural evolution of existing code.

4. **Phase 4 (months, 2-3 months):** Multi-LLM routing — task-aware model selection with dispatch system spawning per-model workers. Builds on Phase 3.

5. **Phase 5 (months, only if validated):** Data plane governance subscriber for post-hoc pattern detection on PTY output. Not blocking, not "deterministic" — but useful for audit/metrics.

6. **Never:** Pre-hook blocking via PTY buffer hold. MCP-level governance is strictly superior for structured operations.

### Execution Status (2026-04-08)

| Phase | Task | TermLink Task | Status | Tests |
|-------|------|---------------|--------|-------|
| 1 | T-1062 | — (framework) | Agent ACs done, human review pending | — |
| 2 | T-1063 | T-902 | Agent ACs done, human review pending | 16 new, 174 pass |
| 3 | T-1064 | T-903 | Agent ACs done, human review pending | 3 new, 155 pass |
| 4 | T-1065 | T-906 | Partial (model passthrough existed) | 3 existing |
| 5 | T-1066 | T-905 | Agent ACs done, human review pending | 9 new, 342 pass |

All TermLink tasks dispatched via `fw termlink dispatch --project /opt/termlink`. Worker sessions created their own tasks in the TermLink project's framework instance. Results verified and updated in framework task files.

## What TermLink Actually Is

TermLink is not "tmux for AI agents." It is not a PTY parser. It is a **structured governance substrate for AI agents** operating through three mechanisms:

1. **MCP tools** — loaded into the agent, governing cross-session operations at the structured API level
2. **Hub orchestrator** — routing, failover, learning, and protection at the inter-session level
3. **Data plane** — high-throughput streaming with future governance frame capability

The analogy is: **the kernel controls the syscall interface, not program output.** TermLink's syscall interface is MCP + RPC. Govern there — not at the byte stream.

Current ecosystem tools (Claude Code hooks, Cursor rules, IDE extensions) all enforce at the application layer. They're valuable, but bypassable by design. TermLink operates at the structured interface layer — below the application, above the OS. That's a genuinely differentiated architectural position.

## Dialogue Log

1. **Q:** Can TermLink replace Claude Code hooks via PTY hacking?
   **A (initial):** Yes, feasible via byte stream interception.
   **A (corrected by TermLink review):** No for PTY parsing. Yes via MCP + hub orchestrator. The PTY read loop is fire-and-forget (`pty.rs:171-219`), no buffer/pause API exists, and parsing ANSI output reliably requires building half a terminal emulator.

2. **Q:** TermLink PTY vs Claude Code native hooks for reliability?
   **A (initial):** Hybrid — native hooks for mechanics, TermLink for governance.
   **A (revised):** MCP-level governance is architecturally correct for cross-session operations. Claude Code hooks remain necessary for native tool calls (Write/Edit/Bash) until an alternative enforcement point exists.

3. **Q:** Key distinction?
   **A:** Constitutional rules belong at the lowest enforceable **structured** layer. For cross-session governance, that's MCP + hub orchestrator. For native tool calls, Claude Code hooks remain the enforcement point (with known gaps G-011, G-015, G-017).

4. **Q:** Value in building a custom terminal?
   **A:** No for emulator (VT compat is a trap). Yes for WezTerm Lua plugin querying existing TermLink RPC — zero new TermLink code, 3-6 weeks.

5. **Q:** Map through the four constitutional directives?
   **A:** Antifragility (bypass registry learns from experience), Reliability (MCP enforcement has no advisory-only gap), Usability (WezTerm chrome + dispatch multi-agent UX), Portability (MCP standard, JSON-RPC 2.0, agent-agnostic).

6. **Q (TermLink project):** Is TermLink-as-governance-substrate the right direction?
   **A:** Partially yes, but not via PTY parsing. The core insight is correct: governance belongs below the application layer. The mechanism is MCP + orchestrator + data plane, not the byte stream. The orchestrator already has governance primitives (bypass registry, route cache, circuit breaker). Extend those.

## Appendix: TermLink Architecture Details

### Control Plane / Data Plane Separation

TermLink has a deliberate dual-channel architecture:

- **Control plane:** JSON-RPC 2.0 over Unix sockets. Methods like `query.output`, `command.inject`, `event.emit`. Structured, request-response, moderate latency.
- **Data plane:** Binary frame protocol over separate Unix sockets. Frame types: Output (0x0), Input (0x1), Resize (0x2), Signal (0x3), Transfer (0x4), Ping (0x5), Pong (0x6), Close (0x7). 22-byte headers with magic, sequence numbers, channel IDs. High-throughput, streaming, low-latency.

### Session Types Are Not Uniform

Not all TermLink sessions are PTY-backed. `SessionContext` has `pty: Option<Arc<PtySession>>`. Sessions created with `termlink register` (no `--shell`) are endpoint-only: RPC, events, KV — no PTY, no scrollback. MCP-registered endpoints are also non-PTY. The governance substrate must work for both PTY and non-PTY sessions — which is why MCP + orchestrator governance is architecturally superior to PTY-level governance.

### TermLink Project Review Source

Full review: `docs/reports/T-1061-termlink-review-feedback.md` (19KB, code-path-specific corrections from Claude Code session in /opt/termlink with full context fabric access).
