---
id: T-020
name: Create resume agent for post-compaction recovery
description: >
  Build an agent that synthesizes current state after context compaction or session breaks. Reads handover, working memory, git status, active tasks, recent commits. Outputs concise "where you are, what to do next" summary. Also keeps working memory current during task transitions.
status: work-completed
workflow_type: build
owner: human
priority: high
tags: [context-fabric, compaction, D2]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T22:10:00Z
last_update: 2026-02-13T22:10:00Z
date_finished: 2026-02-13T22:15:44Z
---

# T-020: Create resume agent for post-compaction recovery

## Design Record

**Problem:** After context compaction (or returning from a break), the agent has:
- A summary of prior conversation (compressed)
- Potentially stale working memory files
- No quick synthesis of "where am I?"

**Approach:** Create a resume agent with two responsibilities:

1. **Resume command** — synthesizes current state:
   - Read latest handover (`.context/handovers/LATEST.md`)
   - Read working memory (`session.yaml`, `focus.yaml`)
   - Check git status (uncommitted changes, recent commits)
   - List active tasks with their status
   - Output: concise "where you are, what to do next"

2. **Working memory updates** — keep state current:
   - Hook into task status changes
   - Update session.yaml when tasks complete
   - Update focus.yaml when focus shifts

**Architecture:** Follow P-006 (hybrid agent):
- `agents/resume/resume.sh` — mechanical operations
- `agents/resume/AGENT.md` — intelligence/guidance

## Specification Record

Acceptance criteria:
- [x] resume.sh `status` command shows synthesized current state
- [x] Output includes: session info, active tasks, uncommitted changes, suggested action
- [x] resume.sh `sync` command updates working memory from actual task state
- [x] AGENT.md documents when to use resume agent
- [x] Works after compaction (tested manually)
- [x] CLAUDE.md updated with Resume Agent section and Quick Reference

## Test Files

- Run `./agents/resume/resume.sh status` after context init
- Manually test after simulated compaction

## Updates

### 2026-02-13T22:10:00Z — task-created [claude-code]
- **Action:** Created task for resume agent
- **Context:** Identified gap after context compaction discussion

### 2026-02-13T22:15:00Z — work-completed [claude-code]
- **Action:** Built resume agent with status, sync, quick commands
- **Output:**
  - `agents/resume/resume.sh` — mechanical operations
  - `agents/resume/AGENT.md` — intelligence/guidance
  - Updated CLAUDE.md with Resume Agent section and Quick Reference
  - Added post-compaction recovery protocol to Session Start Protocol
- **Context:** Fills the gap between planned handovers and unplanned compaction
