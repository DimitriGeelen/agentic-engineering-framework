---
id: T-831
name: "Session quality metrics — session-metrics.sh JSONL analyzer + handover integration"
description: >
  Session quality metrics — session-metrics.sh JSONL analyzer + handover integration

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-04T09:04:38Z
last_update: 2026-04-04T09:10:34Z
date_finished: 2026-04-04T09:10:34Z
---

# T-831: Session quality metrics — session-metrics.sh JSONL analyzer + handover integration

## Context

Build from T-830 GO. Create session-metrics.sh that analyzes JSONL transcripts to extract P0 quality metrics. Integrate into handover frontmatter. See `docs/reports/T-830-agent-b-quality-metrics.md` for full metric design.

## Acceptance Criteria

### Agent
- [x] `agents/context/session-metrics.sh` exists and runs without errors
- [x] Extracts P0 metrics from JSONL: commits_per_turn, first_commit_turn, failed_tool_calls, failed_tool_call_rate, edit_bursts
- [x] Outputs YAML to `.context/working/.session-metrics.yaml`
- [x] handover.sh reads session-metrics.yaml and injects fields into frontmatter
- [x] Timeline displays session quality metrics when available

### Human
- [ ] [RUBBER-STAMP] Session metrics appear in handover frontmatter after next session
  **Steps:**
  1. Generate a handover: `cd /opt/999-Agentic-Engineering-Framework && bin/fw handover`
  2. Check LATEST.md frontmatter for new fields (commits_per_turn, failed_tool_calls, etc.)
  **Expected:** Numeric metric values present in frontmatter
  **If not:** Run `cd /opt/999-Agentic-Engineering-Framework && agents/context/session-metrics.sh` manually

## Verification

bash agents/context/session-metrics.sh 2>&1 | grep -q "metrics"
test -f .context/working/.session-metrics.yaml

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

### 2026-04-04T09:04:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-831-session-quality-metrics--session-metrics.md
- **Context:** Initial task creation

### 2026-04-04T09:10:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
