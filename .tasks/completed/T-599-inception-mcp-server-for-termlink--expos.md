---
id: T-599
name: "Inception: MCP server for TermLink — expose session/file/remote/hub commands as structured tools for agent discovery"
description: >
  Evaluate building an MCP (Model Context Protocol) server that wraps TermLink commands as discoverable tools. Any MCP-capable agent (Claude Code, etc.) could then spawn sessions, transfer files, exec remote commands, and manage the hub without bash wrappers. Consider integration with the framework MCP server being built separately. Key question: which TermLink commands have the most value as MCP tools?

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:05:57Z
last_update: 2026-04-13T06:23:22Z
date_finished: 2026-03-28T17:06:57Z
---

# T-599: Inception: MCP server for TermLink — expose session/file/remote/hub commands as structured tools for agent discovery

## Problem Statement

TermLink commands are invoked via bash wrappers — opaque to MCP tool catalogs. **Key finding:** TermLink already has `termlink mcp serve` built in (stdio transport). Question shifts from "build" to "wire existing into .mcp.json."

## Assumptions

- A1: TermLink MCP server exposes useful tools (NOT YET TESTED)
- A2: MCP provides value beyond bash wrappers (PARTIALLY VALID — for non-Claude Code agents yes)
- A3: Security model is adequate (NOT VALIDATED — MCP tools bypass PreToolUse hooks)
- A4: Framework should manage TermLink MCP config (VALID — T-646 seeds .mcp.json)

## Exploration Plan

1. Audit TermLink MCP server (done — exists as `termlink mcp serve`)
2. Evaluate value vs bash wrappers (done — low for Claude Code, medium for other agents)
3. Assess security implications (done — MCP bypasses hook system)
4. Make recommendation (done — CONDITIONAL GO for minimal wiring)

## Technical Constraints

- MCP tools bypass framework PreToolUse hooks (no task gate, no tier-0)
- TermLink must be installed (optional dependency)
- stdio transport only

## Scope Fence

**IN:** Whether to wire existing `termlink mcp serve` into .mcp.json.
**OUT:** Building custom MCP server. Hub management via MCP.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (TermLink already has MCP server)
- [x] Assumptions tested (4 — 1 valid, 1 partial, 2 untested)
- [x] Go/No-Go recommendation made (CONDITIONAL GO for minimal wiring)

### Human
- [x] [REVIEW] Review findings and approve minimal wiring
  **Steps:**
  1. Read `docs/reports/T-599-termlink-mcp-server.md`
  2. Consider: MCP tools bypass hooks — acceptable?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-599 go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Discuss security concerns

## Go/No-Go Criteria

**GO if:**
- TermLink MCP server works reliably (needs testing)
- Minimal wiring is low-risk (one-line .mcp.json addition)
- D4 (Portability) justifies it

**NO-GO if:**
- MCP server unstable
- Security bypass unacceptable for write operations
- No non-Claude Code agent will use it

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** TermLink MCP server works reliably (needs testing); Minimal wiring is low-risk (one-line .mcp.json addition); D4 (Portability) justifies it

## Decisions

**Decision**: GO

**Rationale**: TermLink MCP server works reliably (needs testing); Minimal wiring is low-risk (one-line .mcp.json addition); D4 (Portability) justifies it

**Date**: 2026-03-28T17:06:57Z
## Decision

**Decision**: GO

**Rationale**: TermLink MCP server works reliably (needs testing); Minimal wiring is low-risk (one-line .mcp.json addition); D4 (Portability) justifies it

**Date**: 2026-03-28T17:06:57Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-24T09:09:48Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-03-28 — inception-research [agent]
- **Research artifact:** docs/reports/T-599-termlink-mcp-server.md
- **Key finding:** TermLink already has `termlink mcp serve` built in — no need to build from scratch
- **Recommendation:** CONDITIONAL GO for minimal wiring (add to .mcp.json + test)

### 2026-03-28T10:41:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T17:06:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** TermLink MCP server works reliably (needs testing); Minimal wiring is low-risk (one-line .mcp.json addition); D4 (Portability) justifies it

### 2026-03-28T17:06:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
