---
id: T-599
name: "Inception: MCP server for TermLink — expose session/file/remote/hub commands as structured tools for agent discovery"
description: >
  Evaluate building an MCP (Model Context Protocol) server that wraps TermLink commands as discoverable tools. Any MCP-capable agent (Claude Code, etc.) could then spawn sessions, transfer files, exec remote commands, and manage the hub without bash wrappers. Consider integration with the framework MCP server being built separately. Key question: which TermLink commands have the most value as MCP tools?

status: captured
workflow_type: inception
owner: human
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:05:57Z
last_update: 2026-03-24T09:09:48Z
date_finished: null
---

# T-599: Inception: MCP server for TermLink — expose session/file/remote/hub commands as structured tools for agent discovery

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

### 2026-03-24T09:09:48Z — status-update [task-update-agent]
- **Change:** horizon: next → later
