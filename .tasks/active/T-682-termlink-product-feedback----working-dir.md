---
id: T-682
name: "TermLink product feedback — --working-dir flag for spawn + MCP as default"
description: >
  F-6: TermLink spawn has no --working-dir flag, requiring a separate cd step after spawn. Also TermLink MCP server should be recommended as default for AI agent integrations. File as feature requests for TermLink product (Vincent). Discovered during T-679.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-28T21:37:45Z
last_update: 2026-03-28T21:37:45Z
date_finished: null
---

# T-682: TermLink product feedback — --working-dir flag for spawn + MCP as default

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

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix
- Fix is scoped and testable

**NO-GO if:**
- Root cause identified with bounded fix
- Fix is scoped and testable

## Recommendation

**Recommendation:** DEFER — external-product feedback, parked pending upstream decision.

**Rationale:** Both items (--working-dir flag, MCP-as-default) are feature requests for the TermLink product itself (separate repo, Vincent-owned), not framework code. Framework workaround for --working-dir: pre-spawn cd via `termlink pty inject` or use `--shell` flag. MCP-as-default is already being used (see `.mcp.json`). No framework-side action needed; hand to upstream when prioritised.

**Evidence:**
- TermLink repo: https://github.com/DimitriGeelen/termlink (external product)
- Framework workaround documented in CLAUDE.md §TermLink Integration
- `.mcp.json` already registers TermLink MCP server

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
