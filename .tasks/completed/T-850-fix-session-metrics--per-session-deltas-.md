---
id: T-850
name: "Fix session metrics — per-session deltas instead of cumulative transcript analysis"
description: >
  Session quality metrics (CPT, error rate, edit bursts, productive ratio) are identical across handovers because session-metrics.sh always analyzes the most recent JSONL file cumulatively. After /compact, multiple handovers within the same Claude Code session all read the same 7551-turn transcript. Fix: track turn offset at session start, compute deltas per handover window.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [agents/context/lib/init.sh, agents/context/session-metrics.sh, agents/handover/handover.sh]
related_tasks: []
created: 2026-04-04T15:04:18Z
last_update: 2026-04-04T22:02:56Z
date_finished: 2026-04-04T22:02:56Z
---

# T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis

## Context

session-metrics.sh analyzes the most recent JSONL file cumulatively. After /compact, multiple
handovers within the same Claude Code session all read the same transcript and produce near-identical
metrics. Fix: record turn offset at session start, compute per-session deltas in handover frontmatter.

## Acceptance Criteria

### Agent
- [x] session-metrics.sh records baseline turn count at session start (`.context/working/.session-turn-offset`)
- [x] Handover frontmatter includes both cumulative AND per-session delta metrics
- [x] Per-session metrics differ from cumulative when multiple handovers occur in same transcript
- [x] Script handles missing offset file gracefully (falls back to cumulative)
- [x] Handover frontmatter shows distinct per-session values after /compact (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

bash -c "test -f agents/context/session-metrics.sh"
grep -q "session_turn_offset\|turn.offset\|OFFSET" agents/context/session-metrics.sh
grep -q "session_commits" agents/handover/handover.sh

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

### 2026-04-04T15:04:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-850-fix-session-metrics--per-session-deltas-.md
- **Context:** Initial task creation

### 2026-04-04T22:02:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-32a00dba
- **Timestamp:** 2026-06-02T15:05:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
