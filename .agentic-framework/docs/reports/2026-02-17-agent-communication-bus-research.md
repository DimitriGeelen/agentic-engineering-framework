---
title: "Inter-Agent Communication Bus: Research & Architecture Analysis"
task: T-108
date: 2026-02-17
status: draft
tags: [multi-agent, communication, architecture, research]
related_gaps: [G-004]
---

# Inter-Agent Communication Bus: Research & Architecture Analysis

## Executive Summary

Research into inter-agent communication patterns — triggered by OpenClaw's architecture and the framework's own G-004 gap (multi-agent collaboration untested). After analyzing OpenClaw, 6 major frameworks, ICLR 2026 research, and our own project history, the recommendation is:

**Build a task-scoped, file-based result ledger** — not a real-time message bus. Agents read at start, write at end. Typed YAML envelopes with automatic size gating. Zero dependencies. Fits existing architecture.

---

## Part 1: OpenClaw Analysis

[OpenClaw](https://github.com/openclaw/openclaw) (formerly ClawdBot) — 200K+ stars, MIT License, built by Peter Steinberger.

### Architecture
- **Centralized Gateway** — WebSocket server on localhost:18789, routes all messages
- **Not a formal bus** — the Gateway is a router, not a message queue
- **Agent isolation by design** — each agent has own workspace, session store, auth profiles
- **Opt-in agent-to-agent messaging** — off by default, must be explicitly allowlisted
- **Append-only session logs** with automatic compaction + memory flush

### Relevant Concepts for Our Framework
| OpenClaw Concept | Our Equivalent | Gap |
|-----------------|----------------|-----|
| Gateway router | Orchestrator (main Claude session) | None — same pattern |
| Session tools (`sessions_send`) | Sub-agent Task dispatch | No cross-agent messaging |
| Append-only session logs | Handover documents | Handovers are narrative, not structured |
| Memory flush before compaction | Checkpoint + emergency handover | Similar pattern |

### Takeaway
OpenClaw's "bus" is really just a central router. Their innovation is in structured session management and messaging platform integration, not in novel agent coordination patterns.

---

## Part 2: Industry Landscape

### Framework Comparison

| Framework | Communication Model | Key Pattern |
|-----------|-------------------|-------------|
| **AutoGen** | Shared transcript, turn-taking | Simple but causes token bloat |
| **CrewAI** | Manager delegates to specialists | Like our sub-agent dispatch |
| **LangGraph** | Graph state object along edges | Deterministic, replayable, checkpointable |
| **MetaGPT** | Assembly-line pipeline, structured outputs | Sequential with typed artifacts |
| **OpenHands** | Event-sourced stream with delegation | Hierarchical with cost tracking |
| **Google A2A** | JSON-RPC + Agent Cards | Emerging standard (Linux Foundation, 50+ partners) |

### ICLR 2026 Key Finding
**Structured, schema-validated messages between agents reduce coordination cost by 41.8%** compared to broadcasting everything (Ripple Effect Protocol). Agents should pass summaries and decisions, not raw context.

### Lightweight Approaches for CLI Systems

| Approach | Latency | Durability | Complexity | Fit |
|----------|---------|------------|------------|-----|
| Shared directory + YAML | 100ms-1s | Excellent | Very low | Best fit |
| SQLite message queue | 10-50ms | Excellent (ACID) | Low | Good but breaks YAML convention |
| Unix sockets | Sub-ms | None | Low | Requires concurrent processes |
| systemd.path units | ~1s | N/A (trigger only) | Medium | Good for cross-session daemon |
| Named pipes (FIFO) | Zero | None | Low | Fatal flaw: blocks ephemeral writers |
| External service (Redis, NATS) | <1ms | Configurable | High | Violates Directive 4 (Portability) |

---

## Part 3: The Trigger Problem

The core unsolved question: if Agent A writes a file, how does Agent B know it's there?

### Analysis by Scenario

**Scenario 1: Intra-session parallel agents**
- Sub-agents dispatched via Task tool are fire-and-forget
- They cannot poll, cannot be interrupted, cannot receive mid-execution messages
- **Real fix:** Pre-flight briefing, not real-time notification. Agent reads task channel BEFORE starting work.

**Scenario 2: Inter-session**
- Session 2's startup protocol drains inbox (structured version of handover)
- No trigger needed — it's pull-at-start

**Scenario 3: Cross-tool (Claude <-> Cursor)**
- Already solved by filesystem — `.context/` IS the cross-tool bus
- Any tool that reads YAML can participate

**Scenario 4: Long-running / daemon-triggered**
- Two practical options:
  - **PostToolUse hook** — already runs after every tool call, can check inbox for ~2ms overhead
  - **systemd.path unit** — watches bus directory, starts handler service on file change

### Mechanism Comparison

| Mechanism | In-Session | Cross-Session | Overhead | Dependencies |
|-----------|-----------|--------------|----------|--------------|
| Pre-flight read | Yes (read at agent start) | N/A | Zero | None |
| PostToolUse hook | Yes (ambient polling) | N/A | ~2ms/tool call | Existing hook infrastructure |
| Resume protocol | N/A | Yes (drain at session start) | One-time | Existing resume agent |
| systemd.path | N/A | Yes (daemon trigger) | Kernel-level | systemd (Linux only) |
| inotifywait | N/A | Yes (daemon trigger) | Kernel-level | inotify-tools package |

### Recommended Two-Tier Approach

1. **In-session:** PostToolUse hook checks `.context/bus/inbox/` after every tool call. Sub-agents read task channel at start of their work. Cost: negligible.
2. **Cross-session:** Session Start Protocol drains bus inbox. Optional: systemd.path unit for push notification.

---

## Part 4: Architectural Thesis

### The Core Insight

> **The framework doesn't need a communication bus. It needs a structured result ledger with a read-before-write protocol.**

The word "bus" implies real-time message passing between concurrent processes. That model is fundamentally incompatible with this framework's execution reality:
- Agents are ephemeral (spawn, work, die)
- The orchestrator is the only persistent process (within a session)
- Between sessions, only files persist

### What the Real Problem Is

Evidence from project history (T-073, T-097):
- **Not** "agents need to talk to each other in real time"
- **Yes** "agent results need to be structured, size-gated, and queryable"
- **Yes** "the orchestrator needs backpressure on result ingestion"

### What's Actually Missing

1. **Pre-flight briefing protocol** — before a sub-agent starts, it reads a task-scoped context file containing messages from the orchestrator and any completed siblings
2. **Result manifest** — sub-agents append to a manifest instead of returning content. Orchestrator reads manifest after all complete
3. **Typed message envelopes** — not free-form text but typed entries: `{from, to, type, payload_ref, timestamp}`

### Proposed Design: Task-Scoped Result Ledger

```
.context/bus/
  channels/
    T-108/                          # Per-task channel
      001-orchestrator-briefing.yaml  # Pre-flight context for sub-agents
      002-investigator-result.yaml    # Finding from sub-agent
      003-auditor-result.yaml         # Finding from sub-agent
  inbox/
    orchestrator/                   # Cross-session messages
  blobs/                            # Large payloads (auto-referenced)
    T-108-investigator-full.yaml    # Dereferenced by 002's payload_ref
```

**Message envelope schema:**
```yaml
id: msg-001
from: investigator
to: orchestrator
task: T-108
timestamp: 2026-02-17T10:30:00Z
type: artifact          # discovery | artifact | warning | dependency
summary: "Found 3 failing tests in auth module"
size_bytes: 245
payload_ref: null       # or path to blob if >2KB
```

**Three operations:**
- `fw bus post <channel> <message>` — append typed message, auto-size-gate
- `fw bus read <channel>` — read all messages (sub-agent at start, orchestrator after completion)
- `fw bus manifest <channel>` — summary of all artifacts produced

### What It Should NOT Be

- Not a pub/sub system (no subscribers, no push, no daemon)
- Not real-time (read at start, write at end)
- Not a replacement for orchestration logic (dependencies = sequential dispatch)
- Not a replacement for handovers (handovers carry narrative judgment; ledger carries structured facts)
- Not infrastructure requiring a running process (pure files, no server)

---

## Part 5: Feasibility Assessment

| Criterion | Assessment |
|-----------|-----------|
| **Sensible?** | Yes — evidence from T-073 (context explosion), G-004 (multi-agent gap) |
| **Valuable?** | Size gate alone prevents context crashes. Auditability is bonus. |
| **Achievable?** | ~2 sessions: 1 inception (protocol), 1 build (CLI + size gate) |
| **Portable?** | Yes — file-based YAML, no provider lock-in |
| **Additive?** | Yes — agents that don't know about the bus still work |

### Build Trigger
Build when: next context explosion from sub-agents, OR first cross-agent coordination need.
Until then: existing Sub-Agent Dispatch Protocol (CLAUDE.md) is sufficient mitigation.

---

## References

- [OpenClaw GitHub](https://github.com/openclaw/openclaw) — Gateway architecture, session tools
- [Google A2A Protocol](https://a2a-protocol.org/latest/) — Agent-to-agent standard
- [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail) — SQLite+Git agent mailbox
- [AgentFS (Turso)](https://turso.tech/blog/agentfs-fuse) — SQLite-backed FUSE agent filesystem
- [ICLR 2026: Ripple Effect Protocol](https://openreview.net/pdf/69f40f61b0874e1186d631ab17393be6be8b0cf1.pdf) — 41.8% coordination cost reduction
- [ICLR 2026: Graph-of-Agents](https://llmsresearch.substack.com/p/what-iclr-2026-taught-us-about-multi) — Multi-agent failure modes
- [systemd.path documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.path.html)
- Framework internal: T-073 (context explosion), T-097 (sub-agent dispatch analysis), G-004 (multi-agent gap)
