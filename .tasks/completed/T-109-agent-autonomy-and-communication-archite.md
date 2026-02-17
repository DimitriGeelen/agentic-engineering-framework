---
id: T-109
name: Structured result ledger protocol
description: >
  Inception: Design and spike a task-scoped, file-based result ledger with typed YAML
  envelopes and automatic size gating. Implements fw bus post/read/manifest CLI.
  Go/no-go: prevents T-073-class context explosion in simulated scenario.
  Research doc: docs/reports/2026-02-17-agent-communication-bus-research.md
  NOTE: Decomposed from original umbrella task. Spikes 2-3 moved to T-110, T-111.

status: work-completed
workflow_type: inception
owner: human
tags: [multi-agent, result-ledger, communication]
related_tasks: [T-097, T-098, T-110, T-111]
created: 2026-02-17T11:19:24Z
last_update: 2026-02-17T15:27:07Z
date_finished: 2026-02-17T15:27:07Z
---

# T-109: Agent autonomy and communication architecture

## Problem Statement

Agents in this framework are ephemeral and isolated. The orchestrator (main Claude Code session) dispatches sub-agents that cannot communicate with each other, cannot be triggered by external events, and lose all context when the session compacts. Three levels of improvement are being explored:

**Level 1 — Structured Result Ledger:** Formalize the existing "write to disk, return path + summary" convention into a protocol with typed message envelopes and automatic size gating. Solves T-073-class context explosions.

**Level 2 — Agent Trigger Mechanism:** Enable external events (file changes, timers, messages) to start agent work without human intervention. systemd.path units, PostToolUse hooks, or daemon-based file watching. Opens door to event-driven agent activation.

**Level 3 — Autonomous Lifecycle Loops:** Automate the compact → handover → resume cycle so agents can work indefinitely on long tasks. Human review only at actual decision points, not at mechanical context transitions.

**For whom:** Any project using the framework with sub-agent dispatch patterns (currently 8% of tasks, growing).

**Why now:** T-073 proved context explosion is a real failure mode. G-004 (multi-agent untested) is the oldest open gap. OpenClaw and industry trends (A2A protocol, ICLR 2026 research) show structured agent communication is maturing. The framework is now published and will be used across projects.

## Assumptions

- A-020: Sub-agents would benefit from reading sibling results before starting work (pre-flight briefing)
- A-021: A file-based result ledger with size gating would prevent context explosion (T-073-class failures)
- A-022: Claude Code's PostToolUse hook can serve as an in-session polling mechanism for bus messages (~2ms overhead)
- A-023: systemd.path can reliably trigger agent work from file events on Linux
- A-024: The compact → handover → resume cycle can be fully automated without losing critical context
- A-025: Autonomous agent loops can be safeguarded by the existing authority model (agents have INITIATIVE, not AUTONOMY)

## Exploration Plan

### Spike 1: Result Ledger Protocol (1 session, time-box: 2 hours)
- Design YAML message envelope schema
- Implement `fw bus post` / `fw bus read` / `fw bus manifest`
- Implement size gate (>2KB → auto-reference to blob)
- Test with simulated sub-agent dispatch

### Spike 2: Agent Trigger via systemd.path (1 session, time-box: 2 hours)
- Create systemd.path unit watching `.context/bus/inbox/`
- Create handler service that logs/processes incoming messages
- Test: write a message file, verify handler fires
- Explore: can the handler invoke Claude Code CLI?
- Document good use cases (cross-session handoff, scheduled audits, CI integration)

### Spike 3: Autonomous Compact-Resume (1 session, time-box: 3 hours)
- Map the exact compact → resume lifecycle step by step
- Identify what's mechanical vs. what needs judgment
- Prototype: checkpoint.sh detects critical → auto-generates handover → marks ready-for-resume
- Explore: how to restart Claude Code session programmatically after compaction
- Test: can a daemon watch for "ready-for-resume" marker and start a new session?

### Research Already Complete
- OpenClaw architecture analysis (see research doc)
- Industry framework comparison (AutoGen, CrewAI, LangGraph, MetaGPT, OpenHands, A2A)
- Trigger mechanism comparison (inotifywait, polling, systemd.path, named pipes)
- Architectural thesis: "result ledger, not message bus"

## Scope Fence

**IN scope:**
- Level 1: Result ledger protocol + CLI commands
- Level 2: systemd.path proof-of-concept on this machine
- Level 3: Automated compact-resume lifecycle design + prototype
- Use case identification for each level
- Portability assessment (does this work with Cursor? Generic agents?)

**OUT of scope:**
- Full pub/sub message broker
- Real-time mid-execution agent-to-agent chat (no mechanism exists)
- External service dependencies (Redis, NATS, etc.)
- Multi-machine agent coordination (single machine only)
- Agent-to-agent communication during execution (impossible with current ephemeral model)
- Changes to Claude Code's Task tool behavior (that's Anthropic's domain)

## Acceptance Criteria

- [x] YAML envelope schema designed (id, task_id, agent_type, timestamp, type, summary, size_bytes, payload/payload_ref)
- [x] fw bus post with inline and blob payloads working
- [x] Size gating: payloads >= 2KB auto-moved to blobs
- [x] fw bus read (single + all) and manifest commands working
- [x] T-073 simulation validates context explosion prevention (~97% savings)
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if (Level 1 only — Levels 2-3 moved to T-110, T-111):**
- Level 1 (ledger) demonstrably prevents context explosion in a simulated T-073 scenario → **YES** (97% savings)
- No new dependencies beyond standard Linux tools → **YES** (bash + Python/PyYAML)
- Works with the existing authority model → **YES** (human sovereignty preserved, bus is a tool not an autonomous actor)

**NO-GO if:**
- File-based approach adds >5ms latency per tool call → **NO** (bus is explicit, not a hook; ~50ms per post)
- Complexity exceeds 3 build tasks → **NO** (1 build task: lib/bus.sh)

## Decisions

**Decision**: GO

**Rationale**: Level 1 result ledger validated. fw bus post/read/manifest deployed. T-073 simulation shows 97% context savings. No new dependencies. Levels 2-3 remain at T-110, T-111.

**Date**: 2026-02-17T15:27:07Z
## Decision

**Decision**: GO

**Rationale**: Level 1 result ledger validated. fw bus post/read/manifest deployed. T-073 simulation shows 97% context savings. No new dependencies. Levels 2-3 remain at T-110, T-111.

**Date**: 2026-02-17T15:27:07Z

## Key Questions to Resolve

1. **Can you inject a prompt into a running Claude Code agent?** If not, mid-execution communication is architecturally impossible — agents can only be briefed before they start.

2. **Can Claude Code be invoked programmatically from a daemon?** If `claude` CLI supports non-interactive mode, systemd can trigger new sessions. If not, the daemon can only queue messages for the next human-initiated session.

3. **What happens to a sub-agent's bus messages if the orchestrator compacts before reading them?** Messages must be on disk (not in context) to survive compaction. This validates the file-based approach.

4. **Where is the authority boundary?** The authority model says agents have INITIATIVE, not AUTONOMY. An autonomous compact-resume loop pushes toward AUTONOMY. What guardrails make this safe? (Proposal: bounded iteration count, mandatory human review every N cycles, kill switch via marker file)

## Updates

### 2026-02-17T11:19:24Z — task-created [task-create-agent]
- **Action:** Created inception task
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-109-agent-autonomy-and-communication-archite.md
- **Context:** Initial task creation

[Chronological log — every action, every output, every decision]

### 2026-02-17T15:27:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Level 1 result ledger validated. fw bus post/read/manifest deployed. T-073 simulation shows 97% context savings. No new dependencies. Levels 2-3 remain at T-110, T-111.

### 2026-02-17T15:27:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
