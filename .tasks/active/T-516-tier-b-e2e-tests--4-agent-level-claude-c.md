---
id: T-516
name: "Tier B E2E tests — 4 agent-level Claude Code governance tests"
description: >
  Write 4 test scripts in tests/e2e/tier-b/ covering: full lifecycle (B1), task gate in agent (B2), inception discipline (B3), error handling (B4). Requires API key, ~$0.50-1 per scenario. Uses tl-claude.sh + pty inject/output. From T-513 inception build task 3.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, termlink, D2]
components: []
related_tasks: []
created: 2026-03-17T21:10:37Z
last_update: 2026-03-17T21:59:29Z
date_finished: null
---

# T-516: Tier B E2E tests — 4 agent-level Claude Code governance tests

## Context

From T-513 inception. Tier B tests spawn Claude Code via TermLink and validate governance behavior with real API calls (~$0.50-1 per scenario). Run manually, not in CI.

## Acceptance Criteria

### Agent
- [x] Test scripts exist in `tests/e2e/tier-b/`
- [x] Scripts syntax-check cleanly (`bash -n`)
- [x] Scripts skip gracefully when ANTHROPIC_API_KEY is unset
- [x] Runner discovers Tier B tests with `--tier b`

### Human
- [ ] [RUBBER-STAMP] Run `tests/e2e/runner.sh --tier b` and verify at least B1 passes
  **Steps:**
  1. Ensure ANTHROPIC_API_KEY is set
  2. Run `tests/e2e/runner.sh --tier b --scenario lifecycle`
  3. Wait for completion (~60-90s)
  **Expected:** B1 full lifecycle test passes (task created, committed, completed)
  **If not:** Check TermLink session output: `termlink pty output fw-e2e-b1 --lines 50 --strip-ansi`

## Verification

test $(ls tests/e2e/tier-b/test-*.sh 2>/dev/null | wc -l) -ge 2
bash -n tests/e2e/tier-b/test-lifecycle.sh

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

### 2026-03-17T21:10:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-516-tier-b-e2e-tests--4-agent-level-claude-c.md
- **Context:** Initial task creation

### 2026-03-17T21:59:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
