---
id: T-582
name: "Inception: Session-scoped agent isolation — session keys + crash recovery for concurrent agents"
description: >
  Two concurrent agents sharing a project corrupt each others focus, session state, and working memory. Already hit in practice: fw-agent + openclaw-eval + 150-skills-manager all active simultaneously. T-560 session-stamped focus is a crude single-writer lock, not true isolation. Investigate: (1) Session key pattern from OpenClaw (agent:<id>:<scope>) giving each agent its own namespace (.context/working/<session-key>/). Blast radius: touches every agent that reads .context/working/. (2) Crash recovery: detect stale sessions (no heartbeat >5min), archive orphaned state, reset focus. Add to fw context init. Already hit: eval agent compacted and sat idle with stale state, previous sessions left orphaned focus files. Research source: /opt/openclaw-evaluation/.context/working/round2-T-018.md (full isolation analysis). OpenClaw source: src/agents/session-manager.ts (session key derivation), src/gateway/runtime-state.ts (process registry + TTL), src/agents/agent-runtime.ts (crash recovery: kill children, flush queues, archive transcript). Related framework: agents/context/lib/focus.sh (current single-file focus), agents/context/lib/init.sh (context init — integration point for crash recovery), T-560 (session-stamped focus — predecessor).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:18:38Z
last_update: 2026-03-23T21:18:38Z
date_finished: null
---

# T-582: Inception: Session-scoped agent isolation — session keys + crash recovery for concurrent agents

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
