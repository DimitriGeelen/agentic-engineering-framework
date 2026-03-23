---
id: T-584
name: "Inception: Structured logging helper — subsystem-tagged log function for framework scripts"
description: >
  Every framework shell script currently does echo message to stderr. No subsystem tags, severity levels, timestamps, or filtering. Debugging requires reading undifferentiated wall of text. OpenClaw has per-module loggers with color coding and dual-sink (console + file). Investigate: log.sh sourced by all agents providing log_info/log_warn/log_error with subsystem tag and timestamp. Writes to .context/working/framework.log. Enables grep subsystem framework.log for targeted debugging. Low effort, high debugging value. Research source: /opt/openclaw-evaluation/.context/working/round2-T-019.md (structured logging section). OpenClaw source: src/util/logger.ts (subsystem logger with color + dual sink). Related framework: lib/compat.sh (existing shared utilities), agents/context/*.sh (all hook scripts — consumers of logging).

status: captured
workflow_type: inception
owner: agent
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:21:55Z
last_update: 2026-03-23T21:21:55Z
date_finished: null
---

# T-584: Inception: Structured logging helper — subsystem-tagged log function for framework scripts

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
