---
id: T-177
name: "Clean up compact hooks for manual-only use"
description: >
  From T-174 GO decision. With auto-compaction disabled, pre-compact.sh and the SessionStart:compact hook fire only on manual /compact. Tasks: (1) Add comment to pre-compact.sh noting it's manual-only now. (2) Review .claude/settings.json PreCompact and SessionStart:compact hooks — simplify or document. (3) Consider if detect_compaction() in checkpoint.sh is dead code. (4) Update compact-log format to distinguish manual vs auto (for diagnostics). (5) Document in CLAUDE.md that /compact is available for manual use but auto-compaction is disabled by design.

status: captured
workflow_type: refactor
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:35Z
last_update: 2026-02-18T18:51:35Z
date_finished: null
---

# T-177: Clean up compact hooks for manual-only use

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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
