---
id: T-578
name: "Inception: PostToolUse loop detection — detect and block repetitive failing tool calls"
description: >
  OpenClaw has 4-detector loop detection system (generic_repeat, known_poll_no_progress, ping_pong, global_circuit_breaker) using SHA256 hashing of canonicalized params + outcome tracking. Our framework has zero protection against agents calling the same failing command 50 times, burning context silently. Investigate: PostToolUse hook that hashes tool_name + params, tracks outcome hashes, warns at 5 repetitions, blocks at 10. Source: T-015 comparative analysis, OpenClaw tool-loop-detection.ts.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:09:25Z
last_update: 2026-03-23T21:09:25Z
date_finished: null
---

# T-578: Inception: PostToolUse loop detection — detect and block repetitive failing tool calls

## Problem Statement

An agent calling the same failing command 50 times burns context silently with zero detection. OpenClaw solved this with a 4-detector loop detection system. We need to investigate whether a PostToolUse loop detector is feasible for our hook architecture.

## Research Artifacts

- `docs/reports/T-549-openclaw-architecture-mapping.md` — Section 2: Agent Runtime, tool call flow
- `docs/reports/T-549-openclaw-design-patterns.md` — Tool policy patterns
- `/opt/openclaw-evaluation/.context/working/round2-T-015.md` — Full comparative analysis: tool call policy enforcement
- OpenClaw source: `src/agents/tool-loop-detection.ts` (4-detector implementation with SHA256 hashing)
- OpenClaw source: `src/agents/pi-tools.ts` (runBeforeToolCallHook integration point)
- Related framework: `agents/context/checkpoint.sh` (existing PostToolUse hook — potential integration point)
- Related framework: `agents/context/budget-gate.sh` (PreToolUse pattern to follow for blocking)

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
