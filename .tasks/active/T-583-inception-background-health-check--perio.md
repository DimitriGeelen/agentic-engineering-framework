---
id: T-583
name: "Inception: Background health check — periodic silent-failure detection for hooks, tasks, focus"
description: >
  Framework is blind between explicit fw doctor / fw audit runs. Hooks can break silently mid-session and nobody notices. Real example: check-project-boundary.sh built but not in settings.json — protection appears to exist but never fires. OpenClaw runs health monitor every 5min detecting stale sockets, stuck sessions, half-dead connections. Investigate: piggyback on PostToolUse checkpoint.sh — every Nth tool call (20?), run quick sanity check: (1) Do all hooks in settings.json resolve to executable scripts? (2) Does focus.yaml parse and point to real task in .tasks/active/? (3) Any task files with broken YAML frontmatter? (4) Is session ID still valid? Cost ~100ms every 20 calls. Connects to T-582 (crash recovery is a health check) and T-578 (loop detection is monitoring). Research source: /opt/openclaw-evaluation/.context/working/round2-T-019.md (full observability analysis). OpenClaw source: src/channels/channel-health.ts (5min background monitor), src/gateway/readiness.ts (aggregated health probe). Related framework: agents/context/checkpoint.sh (existing PostToolUse hook — integration point), agents/context/budget-gate.sh (PreToolUse pattern), bin/fw doctor (existing on-demand diagnostics to reuse).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:21:51Z
last_update: 2026-03-23T21:21:51Z
date_finished: null
---

# T-583: Inception: Background health check — periodic silent-failure detection for hooks, tasks, focus

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
