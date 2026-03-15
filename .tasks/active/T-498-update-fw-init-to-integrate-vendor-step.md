---
id: T-498
name: "Update fw init to integrate vendor step"
description: >
  Modify fw init to: (1) copy framework into project/.agentic-framework/ as part of initialization, (2) generate settings.json with hooks pointing to .agentic-framework/bin/fw hook <name> instead of fw hook <name>, (3) remove framework_path from .framework.yaml (fw resolves from own location), (4) support all three scenarios: new project, existing codebase, post-clone. From T-482 GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [portability, isolation, P0]
components: []
related_tasks: []
created: 2026-03-15T14:01:10Z
last_update: 2026-03-15T14:15:56Z
date_finished: null
---

# T-498: Update fw init to integrate vendor step

## Context

From T-482 GO. `fw vendor` (T-497) exists. Now integrate it into `fw init` so projects get a vendored framework automatically.

## Acceptance Criteria

### Agent
- [x] `fw init` calls `do_vendor` to copy framework into .agentic-framework/
- [x] `settings.json` hooks use `.agentic-framework/bin/fw hook <name>` (project-local path)
- [x] `.framework.yaml` no longer contains `framework_path` field
- [x] Post-clone scenario: if .agentic-framework/ already exists, `fw init` skips vendor step
- [x] `fw init --force` re-vendors even if .agentic-framework/ exists

### Human
- [ ] [RUBBER-STAMP] Run `fw init` on a fresh temp project and verify full isolation
  **Steps:**
  1. `mkdir /tmp/test-init && cd /tmp/test-init && git init`
  2. `fw init --provider claude`
  3. Verify `.agentic-framework/bin/fw` exists and is executable
  4. Verify `.claude/settings.json` hooks reference `.agentic-framework/bin/fw`
  5. Verify `.framework.yaml` has no `framework_path` line
  **Expected:** Self-contained project, no global fw dependency
  **If not:** Note what's missing

## Verification

# settings.json template uses .agentic-framework path
grep -q "agentic-framework/bin/fw hook" lib/init.sh
# .framework.yaml template has no framework_path as required key
grep -q "yaml-8kj" lib/init.sh
# resolve_framework checks for vendored .agentic-framework/
grep -q "agentic-framework/FRAMEWORK.md" bin/fw

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

### 2026-03-15T14:01:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-498-update-fw-init-to-integrate-vendor-step.md
- **Context:** Initial task creation

### 2026-03-15T14:15:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
