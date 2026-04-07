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

## Architecture: Four Dimensions of the Agentic Framework

### 1. Task Dimension
- Every visible pane is owned by a task — no orphan terminals
- Task state visible in terminal chrome: active, blocked, waiting, failed
- Task hierarchy — parent tasks spawning child agent tasks

### 2. Context Dimension
- Context fabric visualized — what knowledge is loaded for this task
- Context drift detection — alert when agent operates outside expected context boundaries
- Session continuity guaranteed — task context survives terminal crash

### 3. Component Dimension
- Which prompt components were assembled for this task
- Component version tracking — did this task use a different system prompt than last run?
- Blast radius visualization when you change a component

### 4. Execution Dimension (new features)

#### Multi-LLM Routing
- TermLink hub intercepts the task before it reaches Claude Code
- Routes based on task type, cost, capability requirements
- Expensive reasoning → Opus, routine files → Haiku, code review → Sonnet
- Deterministic because routing happens at the hub, not inside the agent
- Fallback routing when a model is unavailable or rate-limited

#### Monitor/Management Surface
- Real-time view across all active tasks and their agents
- Which agent is doing what, for how long
- Pause, redirect, or kill a specific agent without killing others
- Task dependency graph — visualize blockers
- Situational awareness, not just logging

#### Metadata Management
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
