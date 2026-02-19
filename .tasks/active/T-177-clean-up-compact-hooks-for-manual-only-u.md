---
id: T-177
name: "Clean up compact hooks for manual-only use"
description: >
  From T-174 GO decision. With auto-compaction disabled, pre-compact.sh and the SessionStart:compact hook fire only on manual /compact. Tasks: (1) Add comment to pre-compact.sh noting it's manual-only now. (2) Review .claude/settings.json PreCompact and SessionStart:compact hooks — simplify or document. (3) Consider if detect_compaction() in checkpoint.sh is dead code. (4) Update compact-log format to distinguish manual vs auto (for diagnostics). (5) Document in CLAUDE.md that /compact is available for manual use but auto-compaction is disabled by design.

status: started-work
workflow_type: refactor
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:35Z
last_update: 2026-02-19T00:29:28Z
date_finished: null
---

# T-177: Clean up compact hooks for manual-only use

## Context

With auto-compaction disabled (D-027), pre-compact.sh and SessionStart:compact hooks only fire on manual `/compact`. Clean up comments, compact-log format, and document manual-only behavior.

## Acceptance Criteria

- [x] pre-compact.sh header updated to note manual-only trigger
- [x] compact-log entries tagged [manual] for diagnostics
- [x] detect_compaction() in checkpoint.sh annotated (still useful, not dead code)
- [x] CLAUDE.md documents that /compact is available for manual use

## Verification

grep -q "manual /compact" /opt/999-Agentic-Engineering-Framework/agents/context/pre-compact.sh
grep -q "manual" /opt/999-Agentic-Engineering-Framework/agents/context/checkpoint.sh
grep -q "/compact" /opt/999-Agentic-Engineering-Framework/CLAUDE.md

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

### 2026-02-18T18:51:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-177-clean-up-compact-hooks-for-manual-only-u.md
- **Context:** Initial task creation

### 2026-02-19T00:29:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
