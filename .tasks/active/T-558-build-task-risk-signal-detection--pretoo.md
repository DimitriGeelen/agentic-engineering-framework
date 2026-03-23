---
id: T-558
name: "Build task risk signal detection — PreToolUse gate requiring inception for high-impact builds"
description: >
  Apply structural risk signals as PreToolUse gate on BUILD tasks (not inception creation). When a build task edits files that trigger risk signals (new subsystem via fabric, cross-subsystem impact >3 dependents, external system files in deploy/infrastructure/, governance layer files, irreversible operations), warn or block: 'This build touches 3 subsystems — did you do inception first?' Signals are observable at build time (unlike inception creation time where future is unknown). Extends check-active-task.sh with ~60 lines. Precedent: budget gate, task gate, build readiness gate. Origin: T-549 steelman/strawman analysis — steelman signals valid but apply to builds not inceptions.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:36:06Z
last_update: 2026-03-23T16:36:06Z
date_finished: null
---

# T-558: Build task risk signal detection — PreToolUse gate requiring inception for high-impact builds

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
