---
id: T-510
name: "Add --force and --no-verify detection to check-tier0.sh"
description: >
  Extend Tier 0 patterns to detect fw task update --force, fw inception decide --force, and --no-verify on framework commands. These are Q4 bypass vectors that should require human approval. From T-477 Spike 3, Option A build task 2.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [governance, enforcement, D2]
components: []
related_tasks: []
created: 2026-03-17T11:34:10Z
last_update: 2026-03-17T11:39:53Z
date_finished: null
---

# T-510: Add --force and --no-verify detection to check-tier0.sh

## Context

From T-477 inception. `--force` on framework commands bypasses sovereignty gates (R-033), AC verification (P-010), and verification gates (P-011). These are Q4 operations that Tier 0 should catch.

## Acceptance Criteria

### Agent
- [x] check-tier0.sh detects `fw task update.*--force` pattern
- [x] check-tier0.sh detects `fw inception decide.*--force` pattern
- [x] Existing Tier 0 patterns (git push --force, rm -rf, etc.) still work
- [x] Existing bats tests pass (34/34)

## Verification

# Test: --force detection blocks
echo '{"tool_name":"Bash","tool_input":{"command":"fw task update T-999 --status work-completed --force"}}' | agents/context/check-tier0.sh 2>/dev/null; test $? -eq 2
# Test: normal fw commands pass
echo '{"tool_name":"Bash","tool_input":{"command":"fw task update T-999 --status started-work"}}' | agents/context/check-tier0.sh 2>/dev/null; test $? -eq 0
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

### 2026-03-17T11:34:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-510-add---force-and---no-verify-detection-to.md
- **Context:** Initial task creation

### 2026-03-17T11:39:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
