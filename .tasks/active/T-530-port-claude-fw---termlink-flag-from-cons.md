---
id: T-530
name: "Port claude-fw --termlink flag from consumer project to upstream"
description: >
  Port the --termlink flag implementation from /opt/995_2021-kosten/.agentic-framework/bin/claude-fw to the upstream bin/claude-fw. Adds TermLink PTY session wrapping so Claude Code sessions can be observed/controlled remotely via termlink attach. Opt-in via --termlink flag or TL_CLAUDE_ENABLED=1 env var. Graceful fallback if termlink not installed. Based on spec at /opt/termlink/docs/specs/T-157-claude-fw-termlink-pickup.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-18T08:31:44Z
last_update: 2026-03-18T08:31:44Z
date_finished: null
---

# T-530: Port claude-fw --termlink flag from consumer project to upstream

## Context

Port of working implementation from consumer project (995_2021-kosten, commit b2dc7b1). Spec: `/opt/termlink/docs/specs/T-157-claude-fw-termlink-pickup.md`. Related: T-503 (TermLink Phase 0).

## Acceptance Criteria

### Agent
- [x] `bin/claude-fw` accepts `--termlink` flag (parsed, not passed to claude)
- [x] `TL_CLAUDE_ENABLED=1` env var enables TermLink mode
- [x] Graceful fallback: if termlink binary not found, prints warning and falls back to direct mode
- [x] TermLink session spawned with name `claude-master-$$` and tags `master,claude,framework`
- [x] Cleanup trap removes TermLink session on script exit
- [x] On auto-restart, reuses existing TermLink session (injects `claude -c`)
- [x] Without `--termlink`, behavior is unchanged from current upstream
- [x] Usage comment in file header documents `--termlink` flag
- [x] CLAUDE.md updated with Remote Session Access section

### Human
- [ ] [REVIEW] Run `claude-fw --termlink` and verify remote attach works
  **Steps:**
  1. In terminal 1: `cd /opt/999-Agentic-Engineering-Framework && claude-fw --termlink`
  2. Note the session name printed (e.g., `claude-master-12345`)
  3. In terminal 2: `termlink attach claude-master-12345`
  4. Verify terminal 2 mirrors the Claude Code session
  5. Type in terminal 2 and verify input reaches Claude
  **Expected:** Full bidirectional mirror of the Claude Code session
  **If not:** Check `termlink list` for session status, `termlink pty output <session>` for recent output

## Verification

# Script parses without syntax errors
bash -n bin/claude-fw
# --termlink flag appears in usage comment
grep -q '\-\-termlink' bin/claude-fw
# TL_CLAUDE_ENABLED env var referenced
grep -q 'TL_CLAUDE_ENABLED' bin/claude-fw
# Cleanup function exists
grep -q 'termlink_cleanup' bin/claude-fw
# CLAUDE.md has Remote Session Access section
grep -q 'Remote Session Access' CLAUDE.md

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

### 2026-03-18T08:31:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-530-port-claude-fw---termlink-flag-from-cons.md
- **Context:** Initial task creation
