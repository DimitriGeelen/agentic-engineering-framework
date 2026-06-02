---
id: T-316
name: "Spike: layered CLAUDE.md (framework base + project overrides)"
description: >
  Test whether Claude Code supports multi-file CLAUDE.md loading or include patterns. If yes: design framework-owned base (12 universal sections, always current) + project-owned overrides (5 project-specific sections). If no: accept fw upgrade as permanent solution. Source: T-306 investigation, Agent 8 findings.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:32Z
last_update: 2026-04-12T07:56:20Z
date_finished: 2026-04-12T07:56:20Z
---

# T-316: Spike: layered CLAUDE.md (framework base + project overrides)

## Problem Statement

CLAUDE.md is 800+ lines. Consumer projects need framework governance (universal) + project-specific overrides. Can Claude Code support layered loading or includes?

## Assumptions

- A1: Claude Code supports multi-file CLAUDE.md or includes (INVALID — no include mechanism)
- A2: Current fw upgrade merge is insufficient (INVALID — works reliably)
- A3: Layered pattern would reduce maintenance (PARTIALLY VALID — but no mechanism exists)

## Exploration Plan

1. Test Claude Code CLAUDE.md loading behavior (done — reads project root + parent dirs, no includes)
2. Evaluate 4 options: symlink, parent dir, build-time merge, git submodule (done)
3. Assess current fw upgrade approach (done — works, 20+ upgrades)
4. Make recommendation (done — NO-GO)

## Technical Constraints

- Claude Code has no include/import directive for CLAUDE.md
- Parent directory loading requires specific directory layout
- Symlinks work but fragile

## Scope Fence

**IN:** Whether Claude Code supports layered CLAUDE.md loading.
**OUT:** Modifying fw upgrade merge logic.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (3 — 2 invalid, 1 partial)
- [x] Go/No-Go recommendation made (NO-GO)

### Human
- [x] [REVIEW] Review findings and confirm NO-GO (overrides corrupted GO decision)
  **Steps:**
  1. Read `docs/reports/T-316-layered-claude-md.md`
  2. Note: previous GO decision had placeholder rationale — this research supersedes it
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-316 no-go --rationale "your rationale"`
  **Expected:** Corrected decision recorded
  **If not:** Discuss concerns

## Go/No-Go Criteria

**GO if:** Claude Code adds include/import directive (not available as of 2026-03)
**NO-GO if:** No include mechanism + fw upgrade merge works (both true)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** NO-GO
**Rationale:** Claude Code has no include/import mechanism for CLAUDE.md. Current fw upgrade merge works reliably (20+ upgrades). GO decision was corrupted (placeholder rationale). Research artifact supersedes it.
**Evidence:**
- A1 (multi-file CLAUDE.md) — INVALID: no include mechanism exists
- A2 (fw upgrade insufficient) — INVALID: works reliably
- Current approach (fw upgrade merge) covers the practical need
- See `docs/reports/T-316-layered-claude-md.md`

## Decisions

**Decision**: GO

**Rationale**: [Criterion 1]; [Criterion 2]

**Date**: 2026-03-27T18:17:06Z
## Decision

**Decision**: GO

**Rationale**: [Criterion 1]; [Criterion 2]

**Date**: 2026-03-27T18:17:06Z

## Updates

### 2026-03-23 — Status check
- Parked at horizon:later. Blocked on Claude Code supporting multi-file CLAUDE.md or include directives. fw upgrade (T-494) covers the practical need for now. Will revisit if Anthropic adds include support.

### 2026-03-27T18:17:06Z — inception-decision [inception-workflow] (CORRUPTED)
- **Action:** Recorded inception decision — DATA INTEGRITY ISSUE
- **Decision:** GO (with placeholder rationale "[Criterion 1]; [Criterion 2]")
- **Superseded by:** 2026-03-28 research below

### 2026-03-28 — inception-research [agent]
- **Research artifact:** docs/reports/T-316-layered-claude-md.md
- **Finding:** Claude Code has no include/import mechanism. Current fw upgrade merge works well.
- **Recommendation:** NO-GO — supersedes corrupted GO decision

### 2026-03-28T12:21:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: later → later

### 2026-04-06T22:23:19Z — status-update [task-update-agent]
- **Change:** horizon: later → later

### 2026-04-12T07:55:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-12T07:56:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2f5b1d40
- **Timestamp:** 2026-06-02T15:02:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
