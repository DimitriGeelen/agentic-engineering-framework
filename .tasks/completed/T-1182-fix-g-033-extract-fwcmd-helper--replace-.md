---
id: T-1182
name: "Fix G-033: extract fw_cmd helper — replace hardcoded bin/fw in error messages with context-aware path"
description: >
  Fix G-033: extract fw_cmd helper — replace hardcoded bin/fw in error messages with context-aware path

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T21:06:16Z
last_update: 2026-04-12T21:09:57Z
date_finished: 2026-04-12T21:09:57Z
---

# T-1182: Fix G-033: extract fw_cmd helper — replace hardcoded bin/fw in error messages with context-aware path

## Context

G-033: `block-task-tools.sh` hardcodes `bin/fw` in user-facing error messages. In consumer projects, `bin/fw` doesn't exist — only `.agentic-framework/bin/fw` or bare `fw`. The `_fw_cmd` helper (T-1143, `lib/paths.sh`) already solves this for other hooks but `block-task-tools.sh` was missed. Related inception: T-1102.

## Acceptance Criteria

### Agent
- [x] `block-task-tools.sh` sources `lib/paths.sh` and uses `_fw_cmd` instead of hardcoded `bin/fw`
- [x] No remaining hardcoded `bin/fw` in user-facing echo statements in `agents/context/block-task-tools.sh`
- [x] Vendored copy synced to `.agentic-framework/agents/context/block-task-tools.sh`
- [x] G-033 marked resolved in concerns.yaml

## Verification

grep -c '_fw_cmd\|_fw=' agents/context/block-task-tools.sh | grep -q '[1-9]'
! grep -q "echo.*'bin/fw" agents/context/block-task-tools.sh

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

### 2026-04-12T21:06:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1182-fix-g-033-extract-fwcmd-helper--replace-.md
- **Context:** Initial task creation

### 2026-04-12T21:09:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-abf2253c
- **Timestamp:** 2026-06-02T14:55:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `block-task-tools.sh` sources `lib/paths.sh` and uses `_fw_cmd` instead of hardcoded `bin/fw`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/paths.sh in: `block-task-tools.sh` sources `lib/paths.sh` and uses `_fw_cmd` instead of hardcoded `bin/fw``
- **AC#3 (Agent)** — Vendored copy synced to `.agentic-framework/agents/context/block-task-tools.sh`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/agents/context/block-task-tools.sh in: Vendored copy synced to `.agentic-framework/agents/context/block-task-tools.sh``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `grep -c '_fw_cmd\|_fw=' agents/context/block-task-tools.sh | grep -q '[1-9]'`
