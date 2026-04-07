# T-1061: TermLink as Deterministic Governance Substrate

## Research Origin

Dialogue between Dimitri and Claude (external session, 2026-04-07). Captured for inception exploration.

## Core Thesis

TermLink's PTY ownership provides **deterministic enforcement** of the prime directive ("nothing gets done without a task"), whereas Claude Code hooks provide only **stochastic enforcement** that is bypassable.

## Key Insight: Deterministic vs Stochastic Enforcement

| Property | TermLink PTY | Claude Code Hooks |
|----------|-------------|-------------------|
| Enforcement model | Deterministic — byte stream passes through TermLink | Stochastic — callback fires if mechanism works |
| Bypass possible | No — transport layer ownership | Yes — API changes, edge cases, hook failures |
| Substrate stability | PTY/Unix sockets — decades stable | Claude Code API — changes every sprint |
| Prime directive | Structural guarantee | Best-effort policy |
| Agent-agnostic | Yes — works with any terminal agent | No — Claude Code specific |

**Principle:** Constitutional rules belong at the lowest enforceable layer. The PTY is that layer.

## Architecture: TermLink Through the Four Constitutional Directives

### 1. Antifragility — System strengthens under stress
- **Task governance as learning loop:** Every task failure passes through TermLink's hub, feeding the healing agent and pattern library
- **PTY-level failure capture:** Tool call failures, crashes, and timeouts are captured at the transport layer — nothing is silently swallowed
- **Metadata as antifragile signal:** Tool call failure patterns, latency spikes, and cost anomalies feed back into routing decisions — the system gets smarter from stress

### 2. Reliability — Predictable, observable, auditable execution
- **Deterministic enforcement:** PTY ownership guarantees the prime directive — no bypass path, no stochastic callbacks
- **Task state in terminal chrome:** Active, blocked, waiting, failed — visible at all times, not buried in logs
- **Monitor/management surface:** Real-time view across all active tasks and agents — which agent is doing what, for how long. Pause, redirect, or kill without guessing
- **Audit trail at transport layer:** Every tool call, every model invocation, every byte passes through TermLink — complete observability by default

### 3. Usability — Joy to use/extend/debug
- **Task-aware terminal chrome:** No orphan terminals — every pane is owned by a task with visible state
- **Context fabric visualization:** What knowledge is loaded for this task, displayed alongside agent output
- **Multi-LLM routing (transparent):** TermLink hub intercepts tasks and routes to optimal model (reasoning → Opus, routine → Haiku, review → Sonnet) — user doesn't manage this manually
- **Fallback routing:** When a model is unavailable or rate-limited, automatic reroute — no broken sessions

### 4. Portability — No provider/language/environment lock-in
- **Agent-agnostic:** PTY interception works with Claude Code, Cursor, any terminal-based agent — not locked to Anthropic's hook API
- **Substrate stability:** PTY/Unix sockets are decades-stable infrastructure vs. vendor APIs that change every sprint
- **Multi-LLM routing as portability feature:** Hub-level routing means switching models is a configuration change, not an architecture change
- **Standards-based:** PTY protocol, JSON-RPC control plane, HMAC security — no proprietary lock-in

## Execution Features (Mapped to Directives Above)

### Multi-LLM Routing (Usability + Portability)
- TermLink hub intercepts the task before it reaches the agent
- Routes based on task type, cost, capability requirements
- Expensive reasoning → Opus, routine files → Haiku, code review → Sonnet
- Deterministic because routing happens at the hub, not inside the agent
- Fallback routing when a model is unavailable or rate-limited

### Monitor/Management Surface (Reliability + Usability)
- Real-time view across all active tasks and their agents
- Which agent is doing what, for how long
- Pause, redirect, or kill a specific agent without killing others
- Task dependency graph — visualize blockers
- Situational awareness, not just logging

### Metadata Management (Antifragility + Reliability)
- Tool call log per task — what was called, when, success/failure rate
- Token utilization per task, per model, per session
- Tool call failure patterns — which tools fail most, under what conditions
- Cost accounting — task-level spend, not just session-level
- Latency distribution — where is time actually going

## Custom Terminal Evaluation

### Why Not Build a Terminal Emulator
- VT100/ANSI/xterm compatibility is months of undifferentiated work
- TermLink already wraps PTY — enforcement point already exists
- Custom terminal gives display ownership, not additional enforcement power

### Middle Ground: Terminal Shell (Not Emulator)
A custom shell that wraps PTY management and adds task-aware UX:
- Task state in terminal chrome
- Multi-pane task governance UI
- First-class context fabric display alongside agent output

### Open Source Candidates for Adaptation
1. **WezTerm** (Rust, 21k+ stars) — GPU-accelerated, Lua scripting API, event system, multiplexer capability
2. **Zellij** (Rust) — WASM plugin system, multi-pane, session persistence
3. **par-term-emu-core-rust** — Rust library for embedding terminal emulation directly into TermLink

### Recommendation
WezTerm's event API or Zellij's plugin system gets task-aware rendering without owning the full stack.

## PTY Intercept Mechanics

### Pre-hook Equivalent
- Pattern-match on Claude Code's output stream (tool call announcements)
- Buffer/pause the stream, run hook logic, then release
- Parse at VT sequence level, not rendered text — more reliable

### Post-hook Equivalent
- Detect completion markers in output
- Trigger downstream actions (notify, log, validate)
- Fire-and-observe, non-blocking

### Challenge: True Blocking Pre-hooks
- PTY is a stream — holding read buffer without forwarding works for pre-hooks
- Proxy PTY layer needed for proper flow control
- Start with post-hooks (non-blocking, immediately useful)

## Dialogue Log

1. **Q:** Can TermLink replace Claude Code hooks via PTY hacking?
   **A:** Yes, feasible. PTY ownership gives byte stream interception. Pre-hooks via pattern matching, post-hooks via completion markers.

2. **Q:** TermLink PTY vs Claude Code native hooks for reliability?
   **A (initial):** Hybrid — native hooks for mechanics, TermLink for governance.
   **A (revised after critical analysis):** TermLink PTY is architecturally correct for reliability because invariant enforcement > mechanical reliability.

3. **Q:** Key distinction?
   **A:** PTY ownership = deterministic. Hook callbacks = stochastic and bypassable. Constitutional rules belong at the lowest enforceable layer.

4. **Q:** Value in building a custom terminal?
   **A:** No for emulator (VT compat is a trap). Yes for shell/chrome that adds task-aware UX. Adapt WezTerm or Zellij rather than building from scratch.

5. **Q:** Four dimensions + features (multi-LLM routing, monitoring, metadata)?
   **A:** TermLink hub is not just a message router — it's a telemetry collection point. Every event passes through it. The terminal becomes a query interface for live operational visibility. "Kubernetes dashboard for agents, not a terminal emulator."

## Reframing

**TermLink is not a "coordination tool." It's a deterministic governance substrate.**

The coordination features are useful, but prime directive enforcement is the core value — something no application-layer hook system can match by design.

This is a genuinely differentiated position: nobody else has PTY-level governance for AI agents.
