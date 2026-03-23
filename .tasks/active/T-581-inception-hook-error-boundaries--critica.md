---
id: T-581
name: "Inception: Hook error boundaries — critical vs advisory hook failure modes"
description: >
  A broken advisory hook (fabric awareness, checkpoint) exits non-zero and blocks the tool call same as a critical hook (task gate, tier0). OpenClaw solves this with error boundaries — failed plugins are marked error but host continues. Investigate: classify framework hooks as critical (must block on failure: check-active-task, check-tier0, budget-gate, check-project-boundary) vs advisory (should warn only: checkpoint, error-watchdog, check-fabric-new-file). Advisory hooks should use || true fallback so non-zero exit logs a warning instead of blocking. Research source: /opt/openclaw-evaluation/.context/working/round2-T-017.md (extension SDK analysis, error boundary section). OpenClaw source: src/plugin-sdk/plugin-entry.ts (try-catch at registration), src/gateway/extensions.ts (error-marked extensions continue). Related framework: .claude/settings.json (hook configuration), bin/fw hook dispatch (line 2270), agents/context/*.sh (all hook scripts).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:11:29Z
last_update: 2026-03-23T21:11:29Z
date_finished: null
---

# T-581: Inception: Hook error boundaries — critical vs advisory hook failure modes

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
