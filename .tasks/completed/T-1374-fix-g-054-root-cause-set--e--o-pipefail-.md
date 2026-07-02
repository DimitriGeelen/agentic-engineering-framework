---
id: T-1374
name: "Fix G-054 root cause: set -e -o pipefail aborts update-task.sh on grep no-match
  in components lookup"
description: >
  Fix G-054 root cause: set -e -o pipefail aborts update-task.sh on grep no-match
  in components lookup

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-20T23:14:34Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T23:23:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1374: Fix G-054 root cause: set -e -o pipefail aborts update-task.sh on grep no-match in components lookup

## Context

G-054 root cause confirmed via bash -x tracing (T-1372):

```
+ for path in $ALL_PATHS
+ case "$path" in
++ grep '^.gitignore.test=' /tmp/tmp.ApoQ8yfdIA
++ head -1
++ cut -d= -f2-
+ comp_id=
+ keylock_release T-9996    ← EXIT trap fires
```

Line 775 of agents/task-create/update-task.sh:
```bash
comp_id=$(grep "^${path}=" "$LOC_TO_ID_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
```

Script runs under `set -euo pipefail` (line 15). When `grep` matches nothing, it returns exit 1. With `pipefail`, the pipeline exits 1. The command-substitution assignment inherits that exit code. Under `set -e`, the script aborts. The EXIT trap fires `keylock_release`, then exits. All blocks after line 775 (including Episodic Generation at line 843) never run.

**Why sandbox reproductions succeeded:** When the commit touched fabric-carded files (like lib/paths.sh or agents/task-create/update-task.sh), `grep` matched and returned 0 — pipeline succeeded, script continued. Failure only manifests when NONE of the non-skipped paths in the commit has a fabric card.

**Why detection lagged:** T-1169's silent-failure detector lives at line 850 — AFTER the abort point. It never got a chance to fire.

## Fix

Append `|| true` to the grep pipeline so the assignment always succeeds:

```bash
comp_id=$(grep "^${path}=" "$LOC_TO_ID_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)
```

Scope is bounded — the intent of `comp_id=""` on no-match is already what the next line handles (`if [ -n "$comp_id" ]`). The pipeline's exit code was never consumed meaningfully; `|| true` restores the expected behavior.

## Acceptance Criteria

### Agent
- [x] Line 775 of update-task.sh has `|| true` appended to the grep pipeline
- [x] Line 769 (ALL_PATHS for loop) also gets `|| true` — guards against root-commit git-diff exit 128
- [x] `bash -n agents/task-create/update-task.sh` passes
- [x] Sandbox reproducer now runs episodic auto-gen successfully — `.last-episodic-gen.log` written AND episodic file created
- [x] Vendored .agentic-framework/agents/task-create/update-task.sh synced
- [x] Regression test at tests/unit/update_task_components_lookup.bats passes; sanity-inverse (revert fix) confirms test fails pre-fix
- [x] Existing tests/unit/update_task_episodic_gen.bats still passes

## Verification

bash -n agents/task-create/update-task.sh
grep -q "cut -d= -f2- || true" agents/task-create/update-task.sh
diff -q agents/task-create/update-task.sh .agentic-framework/agents/task-create/update-task.sh
test -f tests/unit/update_task_components_lookup.bats

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

### 2026-04-20T23:14:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1374-fix-g-054-root-cause-set--e--o-pipefail-.md
- **Context:** Initial task creation

### 2026-04-20T23:23:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d24f866b
- **Timestamp:** 2026-06-02T14:57:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — Existing tests/unit/update_task_episodic_gen.bats still passes
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/update_task_episodic_gen.bats in: Existing tests/unit/update_task_episodic_gen.bats still passes`
