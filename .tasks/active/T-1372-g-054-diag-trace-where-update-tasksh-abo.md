---
id: T-1372
name: "G-054 diag: trace where update-task.sh aborts silently"
description: >
  G-054 diag: trace where update-task.sh aborts silently

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-20T22:59:32Z
last_update: 2026-04-20T23:03:04Z
date_finished: 2026-04-20T23:03:04Z
---

# T-1372: G-054 diag: trace where update-task.sh aborts silently

## Context

Diagnostic inception — triggered by repeated G-054 reproduction during T-1370/T-1371 close. T-1371 landed always-on instrumentation at update-task.sh:845-878 that logs every episodic-gen invocation to `.context/working/.last-episodic-gen.log`. For T-1371's own close, the log was NOT written — the Episodic block never executed (output stopped at "Focus cleared"). Sandbox reproduction with similar task profile (T-9999) runs cleanly. Trigger appears tied to real git history (T-1371 has a matching commit; T-9999 had none). Hypothesis: the auto-populate-components block (lines 749-795) or auto-capture-decisions block (lines 797-837) silently aborts under `set -e` for tasks with matching commits.

## Exploration Findings

- **Spike 1 (minimal task, no commits):** auto-gen runs ✓
- **Spike 2 (full profile: ACs + Verification + Decisions template, no matching commits):** auto-gen runs ✓
- **Spike 3 (real task T-1371 with 1 matching commit touching 3 files):** auto-gen FAILED silently ✗

## Acceptance Criteria

### Agent
- [x] Instrumentation landed in update-task.sh (T-1371)
- [x] Sandbox reproductions confirm code path works in isolation
- [x] G-054 updated with 5th datapoint + new narrower hypothesis
- [x] Recommendation written (see below)

### Human
- [ ] [REVIEW] Next real task close captures `.last-episodic-gen.log` — use for live diagnosis
  **Steps:**
  1. Complete any non-trivial real task: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task update T-XXX --status work-completed`
  2. After: `cat /opt/999-Agentic-Engineering-Framework/.context/working/.last-episodic-gen.log`
  3. If log is missing entirely → episodic block didn't run → bisect lines 727-838 of agents/task-create/update-task.sh
  4. If log exists with non-zero exit → paste stderr into G-054 record
  **Expected:** Log present, exit 0, episodic generated
  **If not:** Add `echo "[tracepoint X]"` markers between Focus cleared (line 719) and Episodic block (line 841), bisect to find the silent abort

## Recommendation

**Recommendation:** DEFER (instrumentation now captures data; next failure reveals root cause)

**Rationale:** After 2 hours of bisection, sandbox cannot reproduce. The trigger is live-git-history dependent and only manifests on real tasks with matching commits. Further speculative work without a captured log is lower-value than the instrumentation already in place. Next real close that fails will produce actionable diagnosis data.

**Evidence:**
- Instrumentation at agents/task-create/update-task.sh:845-878 captures FRAMEWORK_ROOT, PROJECT_ROOT, CONTEXT_DIR, cwd, context.sh stdout/stderr, exit code
- Sandbox tests with T-9999 (minimal + full profile, no commits): auto-gen runs
- Real task T-1371 (with commit): failed silently — pattern now narrowed to `$TASK_COMMITS` or `$ALL_PATHS` being non-empty

## Verification

bash -n agents/task-create/update-task.sh

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

### 2026-04-20T22:59:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1372-g-054-diag-trace-where-update-tasksh-abo.md
- **Context:** Initial task creation

### 2026-04-20T22:59:59Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-04-20T23:03:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
