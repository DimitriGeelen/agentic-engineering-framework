---
id: T-623
name: "Comprehensive consumer fleet health audit — version, hooks, scripts, MCP, cron, TermLink"
description: >
  Comprehensive consumer fleet health audit — version, hooks, scripts, MCP, cron, TermLink

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-25T22:34:59Z
last_update: 2026-03-25T22:37:34Z
date_finished: 2026-03-25T22:37:34Z
---

# T-623: Comprehensive consumer fleet health audit — version, hooks, scripts, MCP, cron, TermLink

## Context

After fleet upgrade (T-618, T-622), need to verify all 7 consumer projects are fully healthy: framework version, hooks, vendored scripts, MCP, cron, TermLink, Claude settings.

## Acceptance Criteria

### Agent
- [x] All 7 consumers report framework v1.3.0
- [x] All consumers have complete hooks in `.claude/settings.json` (14 hooks each, all 12 framework + 2 extras)
- [x] All consumers have vendored scripts in `.agentic-framework/` matching upstream
- [x] MCP server configuration checked per consumer (none configured — expected)
- [x] Cron jobs checked per consumer (only framework has cron — known T-601/T-602)
- [x] TermLink availability checked (v0.1.0 installed)
- [x] Report generated with per-project pass/warn/fail

## Verification

# All consumers at v1.3.0
test "$(for f in /opt/*/.framework.yaml; do [ -f "$f" ] && d=$(dirname "$f") && [ "$d" != "/opt/999-Agentic-Engineering-Framework" ] && grep '^version:' "$f" | awk '{print $2}'; done | sort -u)" = "1.3.0"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-25T22:34:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-623-comprehensive-consumer-fleet-health-audi.md
- **Context:** Initial task creation

### 2026-03-25T22:37:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-96baa3a7
- **Timestamp:** 2026-06-02T15:03:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — All consumers have complete hooks in `.claude/settings.json` (14 hooks each, all 12 framework + 2 extras)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: All consumers have complete hooks in `.claude/settings.json` (14 hooks each, all 12 framework + 2 extras)`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `All consumers`
