# TermLink Project Review — T-1061

**Reviewer:** TermLink project (Claude Code session, /opt/termlink)
**Document reviewed:** T-1061-termlink-governance-substrate.md
**Date:** 2026-04-07

---

## What Aligns With Our Architecture

The document correctly identifies several real capabilities:

1. **TermLink owns PTY sessions.** `PtySession::spawn()` in `crates/termlink-session/src/pty.rs:67-157` uses `libc::openpty()` to create master/slave FDs. We do own the PTY pair. This is accurate.

2. **Hub sees all sessions.** The hub daemon (`crates/termlink-hub/src/server.rs:78-161`) listens on a Unix socket and optionally TCP/TLS. All registered sessions — local and remote — are discoverable via `session.discover` (`crates/termlink-hub/src/router.rs:46`). The claim that "hub sees all sessions" is structurally true for sessions that register.

3. **Event system for cross-session coordination.** The event bus (`crates/termlink-session/src/events.rs`) provides topic-based pub/sub with sequence numbers. Events flow through `event.broadcast`, `event.emit_to`, `event.collect` at the hub level (`router.rs:47-49`). This is a real, working coordination primitive.

4. **Agent-agnostic via MCP.** Our MCP server (`crates/termlink-mcp/src/tools.rs`, 4378 lines, 40+ tools) exposes TermLink to any MCP-capable agent. The `termlink_interact` tool wraps inject + poll + output capture atomically. This does provide agent-agnostic access.

5. **`orchestrator.route` already exists.** The document doesn't acknowledge this, but `router.rs:640-1000+` already implements discover -> forward -> failover -> bypass registry -> route cache -> circuit breaker. This is proto-routing at the hub level, exactly the pattern they describe for multi-LLM routing.

6. **T-577 orphan process problem is real.** We did have this bug. Session deregistration via file removal does not kill the child process. This is a genuine gap between session lifecycle and process lifecycle.

---

## What Is Wrong or Oversimplified

### 1. TermLink Does NOT Parse the PTY Byte Stream

This is the foundational claim of the document, and it's wrong about our current architecture.

The read loop (`pty.rs:171-219`) is fire-and-forget:

```rust
// pty.rs:196-207
Ok(Ok(n)) => {
    let chunk = &buf[..n];
    Self::scan_alternate_screen(chunk, &self.alternate_screen).await;
    let mut scrollback = self.scrollback.lock().await;
    scrollback.append(chunk);
    if let Some(ref tx) = broadcast_tx {
        let _ = tx.send(chunk.to_vec());
    }
}
```

The **only** pattern matching on the stream is scanning for 9-byte alternate screen escape sequences (`\x1b[?1049h` / `\x1b[?1049l`) in `pty.rs:350-371`. That's it. No tool call detection. No "Running bash..." parsing. No structured signal extraction.

The document states: *"Parse in real-time from the byte stream. Same signals, zero latency, no file I/O."* This treats Claude Code's ANSI-formatted, color-coded, cursor-positioned terminal output as if it were structured data. It is not. Parsing "Running bash..." from a stream interleaved with SGR codes (`\x1b[38;5;214m`), OSC sequences (`\x1b]0;...`), cursor movements (`\x1b[H\x1b[2J`), and partial multi-byte reads is a fundamentally harder problem than reading structured JSONL.

### 2. "Buffer/Pause the Stream" Is Not a Mechanism We Have

The document claims TermLink can hold the PTY buffer to implement pre-hooks. This does not exist in our architecture.

The scrollback buffer (`crates/termlink-session/src/scrollback.rs`) is a `VecDeque<u8>` ring buffer with FIFO eviction. There is no pause/resume API. The broadcast channel uses `tx.send()` which never blocks the sender — if subscribers lag, the oldest messages are dropped (256-slot `tokio::sync::broadcast`). The PTY master FD is always readable. The child process writes to the slave FD regardless of whether anyone reads.

To "hold the buffer," you'd have to stop calling `libc::read()` on the master FD. This would fill the kernel's PTY buffer (~4KB), eventually blocking the child process's `write()` syscalls. This isn't governance — it's a deadlock waiting to happen. The child process doesn't know why writes are blocked. Long-running outputs would hang. Interactive programs would freeze. There's no way to "hold, check, release" atomically without risking data corruption.

### 3. Pre-Hook Blocking Requires a Proxy PTY — Not What We Are

The document describes a "proxy PTY layer" and says *"TermLink already does this for `pty inject` and `pty output` — extending to full interception is an engineering step, not an architecture change."*

This conflates three very different things:

- **`pty inject`** (`handler.rs:538-566`): Writes bytes to the PTY master via `pty.write()`. This is input injection, not output interception.
- **`pty output`** (`handler.rs:374-415`): Reads the last N lines/bytes from the scrollback ring buffer. This is snapshot-based history query, not stream interception.
- **`pty interact`** (`cli/commands/pty.rs:12-171`): Captures scrollback snapshot, injects command + unique marker, polls scrollback for marker appearance, diffs output. This is polling with markers, not real-time interception.

A governance proxy would need: TermLink spawns PTY pair A. Claude Code connects to PTY A's slave. TermLink spawns PTY pair B connected to the actual terminal. TermLink sits between A-master (reading Claude's output) and B-master (writing to terminal), with governance logic in between. This is a **fundamentally different architecture** — a MITM PTY proxy. We don't have it. Building it is not "an engineering step" — it changes the relationship between TermLink and the processes it manages.

### 4. Sub-Agent Governance Is Not Solved by Hub Visibility

The document claims: *"G-015 (sub-agent results bypass task gate) exists because sub-agents write to `/tmp/` outside the hook's scope. TermLink hub sees all sessions — parent and child."*

G-015 is about Claude Code's `Task` tool creating in-process sub-agents that write to `/tmp/fw-agent-*.md`. These sub-agents are **threads inside the Claude Code process**, not separate terminal sessions. They don't register with any hub. They don't create PTY sessions. They write to the filesystem directly. TermLink cannot see filesystem writes inside a process it hosts — PTY ownership gives you the byte stream, not the process's syscalls.

Even if Claude Code runs inside a TermLink PTY session, sub-agent writes to `/tmp/` happen via `write()` syscalls that bypass the PTY entirely. The only way to govern those would be syscall interception (seccomp, ptrace) or filesystem-level enforcement (FUSE, namespace isolation) — none of which are in TermLink's scope.

### 5. Multi-LLM Routing Conflates Two Different Problems

The document describes hub-level model routing: *"TermLink hub intercepts the task before it reaches the agent -> Routes based on task type."*

Our `orchestrator.route` (`router.rs:660-1000+`) routes **RPC methods to specialist sessions** based on tags/roles/capabilities. This is session-level routing — "which registered session can handle this method?" — not model-level routing — "which LLM should process this prompt?"

Model routing would require TermLink to be a proxy between the user and multiple AI agent APIs. Claude Code doesn't accept "use Haiku for this" mid-session — it's configured at startup (`claude --model sonnet`). Routing tasks to different models means managing multiple agent processes, each configured for a different model, and directing work to the right one. Our dispatch system (`crates/termlink-cli/src/commands/dispatch.rs`) could spawn workers with different model configs, but the routing intelligence (which task type -> which model) doesn't exist in the hub.

---

## Missing Technical Nuance

### 1. Control Plane / Data Plane Separation

TermLink has a deliberate dual-channel architecture that the document doesn't mention:

- **Control plane:** JSON-RPC 2.0 over Unix sockets (`crates/termlink-session/src/server.rs`). Methods like `query.output`, `command.inject`, `event.emit`. Structured, request-response, moderate latency.
- **Data plane:** Binary frame protocol over separate Unix sockets (`crates/termlink-session/src/data_server.rs`, `crates/termlink-protocol/src/data.rs`). Frame types: Output (0x0), Input (0x1), Resize (0x2), Signal (0x3), Transfer (0x4), Ping (0x5), Pong (0x6), Close (0x7). 22-byte headers with magic, sequence numbers, channel IDs. High-throughput, streaming, low-latency.

Any governance additions would need to decide: which plane? Stream governance (output inspection) belongs on the data plane. Command governance (block/allow decisions) belongs on the control plane. The document treats "PTY interception" as a single concern — it's actually two distinct integration points.

### 2. Session Types Are Not Uniform

Not all TermLink sessions are PTY-backed. The `SessionContext` (`handler.rs:18-59`) has `pty: Option<Arc<PtySession>>`:

```rust
pub struct SessionContext {
    pub registration: Registration,
    pub scrollback: Option<Arc<Mutex<ScrollbackBuffer>>>,
    pub pty: Option<Arc<PtySession>>,  // None for non-PTY sessions
    pub events: Arc<Mutex<EventBus>>,
    pub kv: HashMap<String, serde_json::Value>,
}
```

Sessions created with `termlink register` (no `--shell`) are endpoint-only: they handle RPC, events, and KV, but have no PTY, no scrollback, no stream to intercept. MCP-registered endpoints (`termlink_register` tool, `tools.rs:3635-3670`) are also non-PTY. The governance-substrate thesis assumes all sessions are PTY-backed. Many orchestration use cases aren't.

### 3. The Bypass Registry and Route Cache Are Already Governance Primitives

The document proposes governance at the PTY layer, but doesn't acknowledge that TermLink already has governance at the RPC layer:

- **Bypass registry** (`crates/termlink-hub/src/bypass.rs`): Commands promoted to Tier 3 after `PROMOTION_THRESHOLD` (5) successful orchestrated runs. Denylist patterns prevent dangerous commands from ever being promoted. Failed bypass executions de-promote. This IS deterministic governance.
- **Route cache** (`crates/termlink-hub/src/route_cache.rs`): Caches method -> specialist mappings with confidence scores and hit counts. Stale entries expire. Failed cached routes fall through to full discovery.
- **Circuit breaker** (`crates/termlink-hub/src/circuit_breaker.rs`): Per-session, opens after 3 consecutive transport failures, 60-second cooldown, half-open probing. Prevents routing to dead specialists.

These three layers form an existing governance stack at the hub level. The question isn't "should TermLink do governance?" — it already does. The question is whether PTY-level governance adds value beyond what RPC-level governance provides.

### 4. Scrollback Is Archival, Not Analytical

The scrollback buffer stores raw bytes. There's no indexing, no searchability, no structured event extraction. The ANSI stripping (`handler.rs:374-415`) is regex-based and on-demand. To make scrollback analytically useful for governance, you'd need: structured event extraction from raw bytes -> pattern matching -> decision logic -> action. This is building a terminal parser, which is precisely the VT100 compat trap the document correctly warns against.

### 5. The `pty interact` Marker Pattern Has Latency

`pty interact` polls at 200ms intervals by default (`cli/commands/pty.rs:100`). It captures the scrollback before injection, then polls until a unique marker appears. This means:

- Minimum latency: one poll interval (200ms)
- Depends on the shell echoing the marker (doesn't work in raw mode)
- The marker detection is string-based, not stream-based
- Under load, scrollback can evict the marker before it's polled

This is the closest thing we have to "output analysis," and it's a 200ms-polling hack with known edge cases, not a governance primitive.

---

## Feasibility Assessment

| Capability | Rating | Rationale |
|------------|--------|-----------|
| PTY-level tool call parsing | **Hard** | Requires building a terminal output parser for Claude Code's ANSI-formatted output. Patterns change per Claude Code release. Partial reads split sequences across chunks. No structured protocol to parse — just rendered text. 2-4 months of focused work for reliable detection. |
| Pre-hook blocking via buffer hold | **Requires Redesign** | Current PTY is fire-and-forget (`pty.rs:171-219`). Need a proxy PTY architecture: TermLink-as-MITM between Claude Code and terminal. Changes the fundamental session model. 3-6 months. |
| Post-hook event detection | **Medium** | Extend existing `query.output` + ANSI stripping with pattern matching. Not real-time (polling-based like `pty interact`), but could detect tool completions after the fact. 2-4 weeks. |
| Multi-LLM routing at hub level | **Hard** | `orchestrator.route` routes RPCs to sessions, not models. Need: multiple agent processes per model, task classification logic, result aggregation. Dispatch system has the spawn/collect primitives but not the intelligence layer. 2-3 months. |
| Task-aware terminal chrome | **Medium** | Session metadata (tags, roles, status, KV store) is already available via RPC. WezTerm Lua plugin querying `termlink list --json` and `termlink status` is straightforward engineering. No new TermLink capabilities needed. 3-6 weeks. |
| Real-time metadata collection | **Easy / Hard** | Easy for what we have: session lifecycle metrics, event throughput, RPC latency are already available. Hard for what they want: tool call counts, model token usage, per-tool failure rates all require the tool call parsing from row 1. |

---

## What We Would Add

### 1. The Orchestrator Is the Real Governance Substrate, Not the PTY

The document fixates on PTY-level byte stream interception. But our strongest governance primitive is the `orchestrator.route` chain:

```
orchestrator.route request
  -> bypass registry check (Tier 3 shortcut)
  -> route cache check (learned specialist routing)
  -> session.discover (find matching specialists)
  -> forward + failover (with circuit breaker)
  -> success/failure tracking (bypass promotion, cache update)
```

This is already deterministic. It's already at the hub level. It already provides failover, learning (bypass promotion after 5 successes), and protection (circuit breaker, denylist). Extending THIS — not building PTY parsing — is the natural path to governance.

### 2. The Data Plane Is Where Stream Governance Belongs

If PTY-level governance is truly needed, it belongs on the data plane, not hacked onto the control plane. The binary frame protocol (`crates/termlink-protocol/src/data.rs`) already has:

- Frame types including Signal (0x3) — could add a Governance frame type
- Sequence numbers for ordering
- Channel IDs for multiplexing
- FIN/COMPRESSED/BINARY/URGENT flags

A governance-aware data plane subscriber could: receive Output frames -> parse for patterns -> emit Governance frames back to the session -> session handler blocks/allows based on governance frame. This preserves the existing architecture while adding the interception point.

### 3. MCP Is the Governance Interface, Not PTY Parsing

The document proposes parsing Claude Code's terminal output to detect tool calls. But Claude Code already exposes its operations through MCP tool calls. Our MCP server is loaded INTO Claude Code. Every `termlink_exec`, `termlink_inject`, `termlink_interact` call goes through our code. We can add governance logic at the MCP tool level:

- Before executing `termlink_exec`, check if a task exists
- Before `termlink_spawn`, validate against task scope
- Before `termlink_dispatch`, enforce concurrency limits

This is the existing integration point. It's structured (JSON parameters), reliable (MCP protocol), and doesn't require parsing terminal output. The limitation is that it only governs operations that go through TermLink MCP tools — not Claude Code's native Write/Edit/Bash. But for cross-session orchestration governance, MCP IS the interface.

### 4. The Dispatch System Is the Multi-Agent Governance Primitive

`termlink dispatch` (`cli/commands/dispatch.rs`) already provides:

- Atomic spawn of N workers with tags
- Git worktree isolation (`--isolate`)
- Automatic merge (`--auto-merge`)
- Result collection via hub events
- Dispatch manifest tracking

This is operational multi-agent governance. The gap is: dispatch doesn't make model selection decisions, and it doesn't enforce task-level rules on workers. But extending dispatch with task-awareness (each worker gets a task assignment, reports via events, hub tracks completion) is a natural evolution — 2-4 weeks of work.

---

## The Honest Assessment

### Is TermLink-as-governance-substrate the right direction?

**Partially yes, but not via PTY parsing.**

The document's core insight is correct: governance belongs below the application layer. Claude Code hooks are bypassable, vendor-specific, and have documented gaps (G-011, G-015, G-017). TermLink operates below that layer. This IS a differentiated position.

But the proposed mechanism — PTY byte stream parsing — is the wrong implementation of the right idea. Here's why:

1. **PTY output is rendered text, not structured data.** Parsing it reliably is building half a terminal emulator, which the document itself warns against.

2. **The "deterministic" claim overstates what PTY ownership gives you.** Owning the PTY means you see the bytes. It doesn't mean you understand them. Deterministic enforcement requires deterministic parsing, and ANSI terminal output is not deterministically parseable without full VT state tracking.

3. **The real governance surface is the hub + orchestrator + MCP, not the PTY.** We already have structured, typed, reliable governance primitives at the RPC layer. Extending those is 10x more feasible than building a terminal output parser.

### The real risks:

1. **Scope creep into terminal emulation.** The document correctly warns against this, then proposes mechanisms (tool call parsing from PTY output) that require exactly this.

2. **Coupling to Claude Code's output format.** Claude Code's terminal rendering changes frequently. Any PTY parser would be tightly coupled to a specific version's output patterns. This directly violates D4 (portability).

3. **False confidence from "deterministic" framing.** The PTY ownership is deterministic. The parsing is heuristic. Calling heuristic parsing "deterministic enforcement" creates false confidence that governance is stronger than it actually is.

4. **Opportunity cost.** Months spent on PTY parsing is months not spent on extending the orchestrator, improving dispatch, or building the WezTerm integration — all of which deliver real value sooner.

### What we'd actually recommend:

1. **Phase 1 (now):** Task-aware terminal chrome via WezTerm plugin querying existing TermLink RPC APIs. Zero new TermLink code needed.
2. **Phase 2 (weeks):** Extend `orchestrator.route` with task-type-based routing and model-aware specialist selection. Natural evolution of existing code.
3. **Phase 3 (weeks):** MCP-level governance — add task-gate checks to TermLink MCP tools so cross-session operations are governed.
4. **Phase 4 (months, only if validated):** Data plane governance subscriber for post-hoc pattern detection on PTY output. Not blocking, not "deterministic" — but useful for audit/metrics.
5. **Never:** Pre-hook blocking via PTY buffer hold. The architecture doesn't support it safely, and MCP-level governance is strictly superior for structured operations.

The kernel analogy in the document is apt but misapplied. The kernel enforces memory protection not by parsing the byte stream of program output, but by controlling the syscall interface. TermLink's "syscall interface" is MCP + RPC, not the PTY byte stream. Govern there.
