---
id: T-663
name: "Fix framework hooks — replace bare fw with bin/fw in settings.json"
description: >
  Phase 1 of T-662: Change the framework project's own .claude/settings.json hooks from bare fw (PATH-dependent, resolves to global install) to bin/fw (project-relative). Consumer projects already use .agentic-framework/bin/fw. This is the only project using bare fw. Related: T-662, T-625.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [T-662, hooks, isolation]
components: []
related_tasks: []
created: 2026-03-28T17:06:45Z
last_update: 2026-03-28T17:06:45Z
date_finished: null
---

# T-663: Fix framework hooks — replace bare fw with bin/fw in settings.json

## Context

Phase 1 of T-662 (GO). Framework's `.claude/settings.json` uses bare `fw` for all 13 hooks, resolving via PATH to `$HOME/.agentic-framework/bin/fw` (the global install). Consumer projects already use `.agentic-framework/bin/fw` (vendored relative path). This fix makes the framework project consistent with consumers. Research: `docs/reports/T-662-eliminate-global-install.md`.

## Acceptance Criteria

### Agent
- [ ] All hook commands in `.claude/settings.json` use `bin/fw hook` instead of bare `fw hook` (needs user to regenerate)
- [x] `bin/fw hook check-active-task` responds correctly when piped test JSON
- [x] `lib/init.sh` template for framework-mode hooks uses `bin/fw` (not bare `fw`)
- [x] Vendored copy `.agentic-framework/lib/init.sh` synced

### Human
- [ ] [RUBBER-STAMP] Start a fresh Claude Code session and verify hooks fire (tool counter increments)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat .context/working/.tool-counter`
  2. Start new Claude Code session, run any Write/Edit
  3. Check `.context/working/.tool-counter` again — should have incremented
  **Expected:** Hooks fire normally with `bin/fw` paths
  **If not:** Revert `.claude/settings.json` from git

## Verification

python3 -c "import json; d=json.load(open('.claude/settings.json')); cmds=[h['command'] for g in d['hooks'].values() for e in g for h in e['hooks']]; assert all(c.startswith('bin/fw ') for c in cmds), f'Found non-bin/fw command: {[c for c in cmds if not c.startswith(\"bin/fw \")]}';"
grep -q 'fw_prefix="bin/fw"' lib/init.sh

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

### 2026-03-28T17:06:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-663-fix-framework-hooks--replace-bare-fw-wit.md
- **Context:** Initial task creation
