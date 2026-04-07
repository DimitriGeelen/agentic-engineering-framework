# T-1061: TermLink as Deterministic Governance Substrate

## Research Origin

Dialogue between Dimitri and Claude (external session, 2026-04-07). Enhanced with evidence from 880+ completed tasks, 15 enforcement hooks, 11 tracked concerns, and 2557 traced commits across the Agentic Engineering Framework.

## Core Thesis

TermLink's PTY ownership provides **deterministic enforcement** of the prime directive ("nothing gets done without a task"), whereas Claude Code hooks provide only **stochastic enforcement** that is bypassable. This is not speculation — the framework has 8 months of evidence documenting exactly where application-layer hooks fail.

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

**T-577 (orphan processes):** `termlink run --timeout` deregisters the session but doesn't kill the process. A `claude -p` agent wrote output **65 minutes after** a 900-second timeout. The process was invisible to TermLink, invisible to the framework, still consuming resources. Fixed with a kill watchdog in `fw termlink dispatch`, but the root cause is: session deregistration ≠ process governance.

## The Architectural Insight

The framework has spent 8 months building increasingly sophisticated application-layer enforcement. The result is impressive (98% commit traceability, 4-tier enforcement, 15 hooks), but the architecture has a structural ceiling:

**Hooks react to tool calls. They cannot govern the agent itself.**

- PreToolUse fires *after* Claude Code decides to act, *before* execution — but the agent already consumed context reasoning about the action
- PostToolUse fires *after* execution — it can log, but it cannot undo
- No hook fires on *thinking*, *planning*, or *reasoning* — the most expensive context operations
- Sub-agents inherit zero governance from the parent session
- `--no-verify` on git, `--force` on task completion — bypass paths exist because the substrate allows them

**TermLink PTY ownership inverts this.** The byte stream *must* pass through TermLink. There is no `--no-verify` equivalent for a PTY. The agent cannot reason, plan, or act without its output passing through the governance layer.

## Key Comparison: Deterministic vs Stochastic Enforcement

| Property | TermLink PTY | Claude Code Hooks |
|----------|-------------|-------------------|
| Enforcement model | Deterministic — byte stream ownership | Stochastic — callback fires if API works |
| Bypass possible | No — transport layer | Yes — `--no-verify`, env vars, API changes |
| Substrate stability | PTY/Unix sockets (decades) | Claude Code API (changes per sprint) |
| Prime directive | Structural guarantee | Best-effort policy |
| Agent-agnostic | Yes — any terminal agent | No — Claude Code specific |
| Sub-agent governance | Hub sees all sessions | Sub-agents bypass parent hooks |
| Context cost | Zero — operates below the LLM layer | Non-zero — hooks consume context budget |
| Failure mode | Process-level (detectable, recoverable) | Silent (G-011: advisory-only PostToolUse) |

**Principle:** Constitutional rules belong at the lowest enforceable layer. For "nothing gets done without a task," the PTY is that layer — not the application callback.

## Architecture: TermLink Through the Four Constitutional Directives

### 1. Antifragility — System strengthens under stress

**Current state:** The framework's healing loop (diagnose → classify → suggest → resolve) feeds `patterns.yaml` and `learnings.yaml`. But the loop depends on the agent *choosing* to invoke it. When the agent crashes, ignores an error (G-011), or runs out of context, the learning event is lost.

**With PTY governance:**
- **Every failure is captured at the transport layer** — tool call failures, crashes, timeouts, and silent errors all pass through the PTY stream before reaching the agent. Nothing is silently swallowed because nothing leaves the pipe unobserved.
- **Metadata as antifragile signal:** Tool call failure patterns, latency spikes, and cost anomalies feed routing decisions. The system's routing improves *from* stress — model X fails at task type Y → route Y to model Z.
- **Session continuity across crashes:** TermLink sessions persist across process restarts (T-179 auto-restart already leverages this). The task context survives terminal crashes because it lives in the hub, not in the agent's context window.
- **Evidence:** T-577 showed that timeout != governance. The orphaned `claude -p` process operated for 65 minutes with zero oversight. PTY ownership means: if TermLink can't see the process, the process can't act.

### 2. Reliability — Predictable, observable, auditable execution

**Current state:** 15 hooks provide strong enforcement but with documented holes. PreToolUse can block Write/Edit/Bash. PostToolUse can warn but not block (G-011). Budget gate reads JSONL transcripts for token counting but depends on file availability. The enforcement is reliable when all preconditions hold — and unreliable when they don't.

**With PTY governance:**
- **Deterministic enforcement:** PTY ownership is a structural invariant, not a runtime check. The prime directive becomes a property of the system topology, not a property of the agent's compliance.
- **Complete audit trail:** Every tool call, every model invocation, every byte passes through TermLink. The current `budget-gate.sh` reads the JSONL transcript *after the fact* — PTY governance observes in real-time.
- **No advisory-only gap:** G-011 (PostToolUse cannot block) ceases to exist at the PTY layer. If TermLink decides to block, the bytes don't flow. There is no "exit 0 always" constraint.
- **Sub-agent governance solved:** G-015 (sub-agent results bypass task gate) exists because sub-agents write to `/tmp/` outside the hook's scope. TermLink hub sees all sessions — parent and child — because they all run in PTY sessions registered with the hub.

### 3. Usability — Joy to use/extend/debug

**Current state:** The Watchtower web UI provides visibility into tasks, timeline, costs, fabric, and more (34 endpoints, all healthy). But the *operational* experience — what's happening right now across active agents — requires terminal switching, `termlink list`, `termlink pty output`, etc.

**With PTY governance + terminal chrome:**
- **Task-aware terminal panes:** No orphan terminals. Every pane is owned by a task with visible state (active, blocked, waiting, failed) in the terminal chrome. This is what Watchtower does for the web — TermLink does it for the terminal.
- **Context fabric visualization:** What knowledge is loaded for this task, displayed alongside agent output. Currently this information exists only in `.context/working/focus.yaml` — invisible during active work.
- **Multi-LLM routing (transparent):** TermLink hub intercepts tasks and routes to optimal model. Expensive reasoning → Opus, routine file operations → Haiku, code review → Sonnet. The user doesn't manually manage this. Current state: model selection is hardcoded per session (`claude --model`).
- **Fallback routing:** When a model is unavailable or rate-limited, automatic reroute. Current state: rate limits crash the session. TermLink can retry with a fallback model.

### 4. Portability — No provider/language/environment lock-in

**Current state:** The framework is designed for portability (D4: "No provider/language/environment lock-in; prefer standards"). But enforcement is 100% Claude Code specific — `.claude/settings.json` hooks, Claude Code's PreToolUse/PostToolUse API, CLAUDECODE env var detection. If the user switches to Cursor, Windsurf, or a future agent, all 15 hooks stop working.

**With PTY governance:**
- **Agent-agnostic:** PTY interception works with Claude Code, Cursor, Aider, any terminal-based agent. The governance layer doesn't know or care what agent runs inside the PTY — it governs the *byte stream*, not the *application*.
- **Substrate stability:** PTY and Unix sockets have been stable for decades. Claude Code's hook API changes every release. FP-011 (CLAUDECODE env var) is a concrete example: a vendor env var broke framework dispatch. PTY-level governance is immune to vendor-specific env var changes.
- **Multi-LLM routing as portability:** Hub-level model routing means switching from Anthropic to OpenAI to local models is a configuration change at the hub level, not an architecture change in the agent integration.
- **Standards-based stack:** PTY protocol, JSON-RPC control plane (TermLink's existing architecture), HMAC security — no proprietary lock-in at any layer.

## Execution Features

### Multi-LLM Routing (Usability + Portability)

**Current state:** Model selection is per-session (`claude --model sonnet`). No task-aware routing. All tasks in a session use the same model regardless of complexity. Token costs scale linearly with model capability, even for simple file operations.

**Proposed:**
- TermLink hub intercepts the task *before* it reaches the agent
- Routes based on task type (`inception` → Opus, `build` → Sonnet, `refactor` → Haiku), estimated complexity, and cost budget
- Deterministic because routing happens at the hub, not inside the agent — the agent doesn't choose its own model
- Fallback routing when a model is unavailable or rate-limited — session doesn't die
- **Evidence for value:** The framework tracks token usage per session (handover frontmatter: `token_input`, `token_cache_read`, `token_output`). Current session: 2.4B cached tokens, 2.7M output tokens. Routing simple tasks to Haiku could reduce costs by 60-80% on routine work.

### Monitor/Management Surface (Reliability + Usability)

**Current state:** `termlink list` shows sessions. `termlink pty output <session>` shows recent output. Watchtower `/sessions` page shows session history. But there's no real-time cross-agent dashboard.

**Proposed:**
- Real-time view across all active tasks and their agents — which agent is doing what, for how long
- Pause, redirect, or kill a specific agent without killing others
- Task dependency graph — visualize blockers
- **This is where a custom terminal or WezTerm plugin earns its value** — not rendering text, but providing situational awareness across multiple agents working in parallel

### Metadata Management (Antifragility + Reliability)

**Current state:** Session metrics (`session-metrics.yaml`) track cumulative stats: commits-per-turn, failed tool call rate, productive turns ratio. Token costs tracked via `fw costs`. But this is all *after-the-fact* analysis.

**Proposed:**
- **Real-time** tool call log per task — what was called, when, success/failure rate
- Token utilization per task, per model, per session — not just session-level aggregates
- Tool call failure patterns — which tools fail most, under what conditions (currently: 710 failed tool calls across 17K+ turns, but no per-tool breakdown)
- Cost accounting at task level — not just session level
- Latency distribution — where is time actually going
- **Key insight:** This metadata collection is essentially free at the PTY layer. TermLink is already in the byte stream. Parsing tool calls from the stream adds negligible overhead compared to the current approach (reading JSONL transcripts after the fact via `budget-gate.sh`).

## Custom Terminal Evaluation

### Why Not Build a Terminal Emulator
- VT100/ANSI/xterm compatibility alone is months of undifferentiated engineering
- TermLink already wraps PTY — the enforcement interception point already exists
- A custom terminal gives *display* ownership, not additional *enforcement* power beyond what TermLink's PTY wrapper already provides

### Middle Ground: Terminal Shell (Not Emulator)
A custom shell/chrome that wraps PTY management and adds task-aware UX:
- Task state in terminal chrome (not text output)
- Multi-pane task governance UI without depending on tmux/screen
- First-class context fabric display alongside agent output
- Session history with task-level drill-down

### Open Source Candidates for Adaptation

1. **WezTerm** (Rust, 21k+ stars) — GPU-accelerated, cross-platform, Lua scripting API with event hooks. The multiplexer capability aligns with TermLink's hub architecture. Most viable for integration: embed task governance as Lua events.
2. **Zellij** (Rust) — WASM plugin system, multi-pane, session persistence. Plugin architecture is cleaner for isolation — task governance as a WASM plugin is architecturally elegant. But Zellij is a multiplexer, not an emulator — still depends on underlying terminal.
3. **par-term-emu-core-rust** — Rust terminal emulator library with VT100/VT220/VT320/VT420 compatibility. Could be embedded directly into TermLink as a crate for deep integration — but adds the VT compat maintenance burden.

**Recommendation:** WezTerm for immediate value (Lua event API), evaluate Zellij's WASM plugin system for cleaner long-term architecture.

## PTY Intercept Mechanics

### What Claude Code Emits (Parseable Signals)

Claude Code announces tool use in its output stream before executing. These are structured signals, not random text:
- Tool call start: `"Running bash..."`, `"Writing file..."`, `"Reading file..."`
- Tool results: exit codes, file contents, error messages
- Context budget markers: token counts in JSONL transcript
- Session lifecycle: compaction, handover, restart signals

**Current framework approach:** Parse these signals *after the fact* from the JSONL transcript (`budget-gate.sh` reads `~/.claude/projects/*/sessions/*.jsonl`).

**PTY approach:** Parse in real-time from the byte stream. Same signals, zero latency, no file I/O.

### Pre-hook Equivalent
- Detect tool call announcement in the PTY output stream
- Buffer/pause the stream before the tool executes
- Run governance logic (task gate, tier 0 check, budget check)
- Release the buffer to continue, or inject a cancel signal
- **Advantage over current hooks:** PreToolUse hooks run as shell scripts and add latency (50-200ms per call). PTY parsing can be sub-millisecond in Rust.

### Post-hook Equivalent
- Detect tool completion markers in output
- Trigger downstream actions (error watchdog, dispatch check, loop detection)
- Fire-and-observe, non-blocking — but unlike G-011, can *also* block if needed
- **Key difference from current PostToolUse:** At the PTY layer, "post" hooks can still block the next action by holding the buffer. G-011 ceases to exist.

### Challenge: True Blocking Pre-hooks
- PTY is a stream — holding the read buffer without forwarding works for pre-hooks before Claude acts
- Need a proxy PTY layer: TermLink sits between Claude Code's actual PTY and the terminal, acting as a man-in-the-middle governance proxy
- TermLink already does this for `pty inject` and `pty output` — extending to full interception is an engineering step, not an architecture change

### Pragmatic Path
1. **Phase 1:** Post-hook equivalents (non-blocking, immediately useful) — parse tool completions, log metadata, detect failures
2. **Phase 2:** Pre-hook equivalents for critical gates (task gate, tier 0) — buffer-and-gate on tool call announcements
3. **Phase 3:** Full flow control proxy — deterministic equivalent of all 15 current hooks
4. **Phase 4:** Multi-LLM routing — task-aware model selection at the hub level

## What This Actually Is

TermLink is being described as a "cross-terminal session communication tool." That description undersells it by an order of magnitude.

**TermLink is a deterministic governance substrate for AI agents.**

The coordination features (hub, sessions, events, file transfer) are useful. But the core value — the thing that no application-layer hook system can match — is **PTY-level enforcement of constitutional rules**.

The analogy is not "tmux for AI agents." The analogy is: **the kernel enforces memory protection, not the application.** TermLink enforces the prime directive at the transport layer, not at the application layer.

Current ecosystem tools (Claude Code hooks, Cursor rules, IDE extensions) all enforce at the application layer. They're valuable, but bypassable by design. TermLink is the only project in the ecosystem that operates below the application layer.

That's a genuinely differentiated architectural position. Nobody else has this.

## Dialogue Log

1. **Q:** Can TermLink replace Claude Code hooks via PTY hacking?
   **A:** Yes, feasible. PTY ownership gives byte stream interception. Pre-hooks via pattern matching, post-hooks via completion markers.

2. **Q:** TermLink PTY vs Claude Code native hooks for reliability?
   **A (initial):** Hybrid — native hooks for mechanics, TermLink for governance.
   **A (revised after critical analysis):** TermLink PTY is architecturally correct for reliability because invariant enforcement > mechanical reliability. Making TermLink subordinate to Claude Code hooks inverts the dependency and makes the prime directive advisory, not enforced.

3. **Q:** Key distinction?
   **A:** PTY ownership = deterministic. Hook callbacks = stochastic and bypassable. Constitutional rules belong at the lowest enforceable layer.

4. **Q:** Value in building a custom terminal?
   **A:** No for emulator (VT compat is a trap). Yes for shell/chrome that adds task-aware UX. Adapt WezTerm or Zellij rather than building from scratch.

5. **Q:** Map through the four constitutional directives + features?
   **A:** TermLink hub is not just a message router — it's a telemetry collection point. Every event passes through it. The terminal becomes a query interface for live operational visibility. "The kernel for AI agent governance, not a terminal emulator."
