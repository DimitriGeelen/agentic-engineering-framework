---
id: T-1372
name: "G-054 diag: trace where update-task.sh aborts silently"
description: >
  G-054 diag: trace where update-task.sh aborts silently

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-20T22:59:32Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T23:03:04Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] [REVIEW] Next real task close captures `.last-episodic-gen.log` — use for live diagnosis
  **Steps:**
  1. Complete any non-trivial real task: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task update T-XXX --status work-completed`
  2. After: `cat /opt/999-Agentic-Engineering-Framework/.context/working/.last-episodic-gen.log`
  3. If log is missing entirely → episodic block didn't run → bisect lines 727-838 of agents/task-create/update-task.sh
  4. If log exists with non-zero exit → paste stderr into G-054 record
  **Expected:** Log present, exit 0, episodic generated
  **If not:** Add `echo "[tracepoint X]"` markers between Focus cleared (line 719) and Episodic block (line 841), bisect to find the silent abort

## Recommendation

**Recommendation:** GO — close as superseded. T-1374 used this task's instrumentation to find and fix the root cause.

**Rationale:** The Human AC ("next real task close captures `.last-episodic-gen.log` — use for live diagnosis") was satisfied during T-1374's work. The instrumentation revealed the abort point via `bash -x` tracing; root cause was grep/git pipelines inside `$(...)` under `set -euo pipefail` aborting via command-substitution assignment before the Episodic block ran. Fix landed as `|| true` on update-task.sh:769,775. G-054 flipped to `mitigated`. L-236 captured the pattern. Regression test pins it.

**Evidence:**
- Root cause found: `set -euo pipefail` + grep-no-match in `$(...)` assignments aborts script via EXIT trap before reaching instrumented block
- Fix: commit 65a8a76e (update-task.sh:769,771-772 + 775-779) — `|| true` on ALL_PATHS git loop and comp_id grep pipeline
- Regression test: tests/unit/update_task_components_lookup.bats (sanity-inverse verified)
- Concern G-054: flipped to `mitigated` in `.context/project/concerns.yaml`
- Learning L-236: captured in `.context/project/learnings.yaml` — "set -euo pipefail silently aborts via command-substitution assignments"
- T-1374's own close: log captured, exit 0, episodic generated — the AC step executed successfully on real task close

## Verification

bash -n agents/task-create/update-task.sh

## Decision

**Decision**: GO (close as superseded)

**Rationale**: T-1374 used the instrumentation landed by T-1371 (this task's sibling) to find and fix the root cause. Human AC "Next real task close captures .last-episodic-gen.log" was satisfied via T-1374's work — the log was written, exit 0, episodic generated. G-054 flipped to `mitigated`; L-236 captures the pattern.

**Date**: 2026-04-21T20:37:23Z

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

### 2026-04-21T20:37:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — close as superseded. T-1374 used this task's instrumentation to find and fix the root cause.

Rationale: The Human AC ("next real task close captures `.last-episodic-gen.log` — use for live diagnosis") was satisfied during T-1374's work. The instrumentation revealed the abort point via `bash -x` tracing; root cause was grep/git pipelines inside `$(...)` under `set -euo pipefail` aborting via command-substitution assignment before the Episodic block ran. Fix landed as `|| true` on update-task.sh:769,775. G-054 flipped to `mitigated`. L-236 captured the pattern. Regression test pins it.

Evidence:
- Root cause found: `set -euo pipefail` + grep-no-match in `$(...)` assignments aborts script via EXIT trap before reaching instrumented block
- Fix: commit 65a8a76e (update-task.sh:769,771-772 + 775-779) — `|| true` on ALL_PATHS git loop and comp_id grep pipeline
- Regression test: tests/unit/update_task_components_lookup.bats (sanity-inverse verified)
- Concern G-054: flipped to `mitigated` in `.context/project/concerns.yaml`
- Learning L-236: captured in `.context/project/learnings.yaml` — "set -euo pipefail silently aborts via command-substitution assignments"
- T-1374's own close: log captured, exit 0, episodic generated — the AC step executed successfully on real task close

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9241844
- **Timestamp:** 2026-06-02T14:57:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
