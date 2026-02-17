---
id: T-110
name: Agent trigger via systemd.path
description: >
  Spike: Can systemd.path units reliably trigger agent work from file events? Test on this machine. Go/no-go: file event triggers handler within 5 seconds. Spawned from T-109 decomposition. Research: docs/reports/2026-02-17-agent-communication-bus-research.md Part 3.

status: work-completed
workflow_type: inception
owner: human
tags: []
related_tasks: []
created: 2026-02-17T11:32:21Z
last_update: 2026-02-17T15:31:07Z
date_finished: 2026-02-17T15:31:07Z
---

# T-110: Agent trigger via systemd.path

## Problem Statement

Can systemd.path units reliably trigger agent work from file events? This enables cross-session agent coordination: a daemon watches for messages and can invoke Claude Code CLI in non-interactive mode to process them.

## Assumptions

- A-023: systemd.path can reliably trigger agent work from file events on Linux → **VALIDATED** (<1s latency)
- A-026: Claude Code CLI supports non-interactive invocation from daemons → **VALIDATED** (`claude -p` with --print mode)

## Exploration Plan

1. Check systemd availability → systemd v255, .path units functional (3 active)
2. Create .path unit watching .context/bus/inbox/ → DONE
3. Create handler .service → DONE
4. Test: file event triggers handler within 5s → PASS (<1s)
5. Check Claude Code CLI → PASS (v2.1.37, supports -p non-interactive mode)

## Scope Fence

**IN:** systemd.path proof-of-concept, latency measurement, Claude CLI feasibility
**OUT:** Full autonomous loop implementation (T-111), production handler logic

## Acceptance Criteria

- [x] systemd.path unit created and active
- [x] Handler triggered by file event within 5 seconds (<1s achieved)
- [x] Claude Code CLI non-interactive mode confirmed
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- File event triggers handler within 5 seconds → **YES** (<1s)
- No root access issues → **YES** (running as root, but .path units work in user mode too with `--user`)
- Claude Code CLI can be invoked programmatically → **YES** (`claude -p "prompt"`)

**NO-GO if:**
- systemd.path is unreliable → **NO** (rock solid)
- Root access required and can't be guaranteed → **NO** (user units available too)
- Claude Code requires interactive terminal → **NO** (-p mode works)

## Decisions

**Decision**: GO

**Rationale**: systemd.path validated: <1s trigger latency, Claude Code CLI supports non-interactive mode (claude -p), no new dependencies. Ready for build task.

**Date**: 2026-02-17T15:31:07Z
## Decision

**Decision**: GO

**Rationale**: systemd.path validated: <1s trigger latency, Claude Code CLI supports non-interactive mode (claude -p), no new dependencies. Ready for build task.

**Date**: 2026-02-17T15:31:07Z

## Spike Results

**Environment:** systemd v255, Ubuntu 24.04, root user
**Path unit:** fw-bus-watcher.path watching .context/bus/inbox/ (PathChanged)
**Handler:** bus-handler.sh — logs, moves messages to .processed/
**Latency:** <1s (file written at 15:29:55Z, handler completed at 15:29:55Z)
**Claude CLI:** v2.1.37, `-p`/`--print` mode for non-interactive invocation, supports `--max-budget-usd` for cost bounding

**Key finding:** `claude -p "Process inbox messages for project X" --cwd /path/to/project` can be invoked by the systemd handler. Combined with `--max-budget-usd` and `--allowed-tools`, this enables bounded autonomous agent invocation.

### 2026-02-17T15:28:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T15:31:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** systemd.path validated: <1s trigger latency, Claude Code CLI supports non-interactive mode (claude -p), no new dependencies. Ready for build task.

### 2026-02-17T15:31:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
