---
id: T-469
name: "Inception: Structural remediation for pickup-message governance bypass"
description: >
  A pickup message from another agent session caused complete governance bypass: agent created a build task and immediately started editing framework source files (bin/fw), building Watchtower pages, and creating feature branches — without inception, without scoping, without AC. Human had to intervene 3 times. Root cause: no structural gate distinguishes 'copy 4 files' from 'build a new subsystem'. Task gate passed because a task existed, but having a task is not authorization to build. Investigate: (1) What structural gap allowed this? (2) Why did the agent treat a pickup message as a build instruction? (3) What gate could have caught this — inception requirement for new subsystems? New file count threshold? PR scope check? (4) Is this a new gap class or an instance of G-017 (execution gates don't cover proposal layer)?

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: [governance, enforcement, G-020]
components: []
related_tasks: []
created: 2026-03-12T18:41:27Z
last_update: 2026-03-12T20:50:07Z
date_finished: 2026-03-12T20:50:07Z
---

# T-469: Inception: Structural remediation for pickup-message governance bypass

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Acceptance Criteria

### Agent
- [x] Gap classification complete (G-020 is new class)
- [x] Root cause identified (task gate checks existence not scope)
- [x] Structural options assessed (5 options, 2 recommended)
- [x] GO decision recorded

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

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Root cause is clear and fix is bounded
- False positive rate is low

**NO-GO if:**
- Fix requires changes to multiple subsystems
- False positive rate is high

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Root cause: task gate checks existence not scope. Fix: Option A (scope-aware task gate) + Option E (CLAUDE.md pickup message rule).

**Date**: 2026-03-12T20:49:42Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-12T19:30:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause: task gate checks existence not scope. Fix: Option A (scope-aware task gate — block build tasks with placeholder ACs, ~20 lines in check-active-task.sh) + Option E (CLAUDE.md pickup message rule).


### 2026-03-12T20:50:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
