---
id: T-1492
name: "Pickup: review.sh emit_review silent-exit on missing top-level Recommendation line + pipefail interaction (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-154. Type: bug-report.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-26T10:57:02Z
last_update: 2026-04-26T11:03:23Z
date_finished: null
source_task_id_in_origin: T-154
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1492: Pickup: review.sh emit_review silent-exit on missing top-level Recommendation line + pipefail interaction (from 003-NTB-ATC-Plugin)

## Context

Pickup from `003-NTB-ATC-Plugin/T-154`. Inception task body lacked an unindented
`**Recommendation:**` line; `lib/review.sh:130`'s grep pipeline returned non-zero
under `set -euo pipefail`, aborting `emit_review` mid-flight via command
substitution. The `.context/working/.reviewed-T-XXX` marker was never created,
so `fw inception decide` later refused with "Task review required" — with no
clue that review.sh had silently aborted. Same family as L-282 (silent gate
failure). Fix variant (c): widen pattern + neutralize pipefail + log warning.

## Acceptance Criteria

### Agent
- [ ] `lib/review.sh:130` grep pipeline ends with `|| true` so command-substitution exit code can never abort emit_review under `set -euo pipefail`
- [ ] Pattern widened to match indented `**Recommendation:**` and skip HTML-commented variants
- [ ] When no recommendation is found, emit_review prints a clear YELLOW warning to stderr (not silent fallback)
- [ ] Regression bats test added that runs emit_review under `set -euo pipefail` on an inception task with no `**Recommendation:**` line and asserts (a) exit 0, (b) `.reviewed-T-XXX` marker exists, (c) warning text appears in stderr
- [ ] Existing `tests/unit/lib_review.bats` tests still pass

## Verification

bash -n lib/review.sh
bats tests/unit/lib_review.bats

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

### 2026-04-26T10:57:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1492-pickup-reviewsh-emitreview-silent-exit-o.md
- **Context:** Initial task creation

### 2026-04-26T11:03:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** applying fix (c)
