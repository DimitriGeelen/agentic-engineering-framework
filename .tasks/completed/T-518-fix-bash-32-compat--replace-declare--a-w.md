---
id: T-518
name: "Fix bash 3.2 compat — replace declare -A with POSIX-safe lookups (macOS)"
description: >
  macOS ships bash 3.2 which lacks declare -A (bash 4+). Three files crash: update-task.sh:599 (component auto-populate), audit.sh:2775 (trend analysis), diagnose.sh:9 (failure classifier). Replace with parallel arrays or temp-file lookup. Also grep for other declare -A usage and consider fw doctor bash-version warning. Related: T-028 episodic already flagged associative arrays as fragile.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [portability, macos, bash, D4]
components: [C-004, agents/healing/lib/diagnose.sh, agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-17T22:09:02Z
last_update: 2026-04-30T20:48:15Z
date_finished: 2026-03-17T22:11:22Z
---

# T-518: Fix bash 3.2 compat — replace declare -A with POSIX-safe lookups (macOS)

## Context

macOS ships bash 3.2 which lacks `declare -A` (bash 4+). Three framework files use associative arrays, causing crashes on macOS. Bug report from TermLink project (010-termlink). Related: T-028 episodic flagged associative arrays as fragile.

## Acceptance Criteria

### Agent
- [x] No `declare -A` in agents/ bin/ lib/
- [x] update-task.sh component auto-populate works (bash -n passes)
- [x] audit.sh trend analysis works (bash -n passes)
- [x] diagnose.sh failure classifier works (bash -n passes)

### Human
- [ ] [RUBBER-STAMP] Verify on macOS bash 3.2
  **Steps:**
  1. Run `fw task update T-XXX --status work-completed` on macOS
  2. Run `fw audit`
  3. Run `fw healing diagnose T-XXX`
  **Expected:** No `declare: -A: invalid option` errors
  **If not:** Check which file still uses declare -A: `grep -rn "declare -A" agents/`

## Verification

bash -n agents/task-create/update-task.sh
bash -n agents/audit/audit.sh
bash -n agents/healing/lib/diagnose.sh
# No uncommented declare -A in any of the three files
test -z "$(grep -n '^[^#]*declare -A' agents/task-create/update-task.sh agents/audit/audit.sh agents/healing/lib/diagnose.sh 2>/dev/null)"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 4 Agent ACs verified — no `declare -A` remains in framework source, three syntax-sensitive sites pass `bash -n`. The `[RUBBER-STAMP]` Human AC is a deterministic 3-command run on macOS — could be Agent AC with a macOS gate-host (none currently). Risk surface is low: bash 3.2 compat is a portability win, regression mode would be visible immediately on any macOS run.

**Evidence:**
- `grep -rn "declare -A" agents/ bin/ lib/` returns nothing
- update-task.sh (component auto-populate), audit.sh (trend analysis), diagnose.sh (failure classifier) all pass `bash -n`
- POSIX-safe lookup pattern (lookup-by-loop or sed) used as replacement

## Updates

### 2026-03-17T22:09:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-518-fix-bash-32-compat--replace-declare--a-w.md
- **Context:** Initial task creation

### 2026-03-17T22:11:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next
