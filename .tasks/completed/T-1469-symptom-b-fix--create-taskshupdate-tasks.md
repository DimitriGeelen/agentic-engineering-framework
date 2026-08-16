---
id: T-1469
name: "Symptom B fix — create-task.sh/update-task.sh YAML emit produces valid frontmatter
  (regression bats)"
description: >
  Symptom B fix — create-task.sh/update-task.sh YAML emit produces valid frontmatter
  (regression bats)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh, 
      tests/scripts/yaml_parse_all_tasks.py, 
      tests/unit/update_task_yaml_components_emit.bats]
related_tasks: []
created: 2026-04-25T19:21:27Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T19:27:23Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1469: Symptom B fix — create-task.sh/update-task.sh YAML emit produces valid frontmatter (regression bats)

## Context

T-1444 inception GO, Symptom B branch.

`update-task.sh:805-806` replaces `^components:.*` with flow-style `components: [...]`. When the original was block-style:

```yaml
components:
  - bin/fw
  - bin/fw-shim
```

…the sed only touches the `components:` line. The block continuation lines (`  - bin/fw\n  - bin/fw-shim\n`) remain in the file as orphan list items, producing invalid YAML. Watchtower's scanner then crashes on parse → blank queues (the symptom that triggered T-1468 cleanup).

T-1278 commit `c4f0c14d` is the canonical reproducer. T-1278 + T-1279 (both with block-style `components`) plus the cascading `description: >` files (T-1444, T-444, T-453, T-675) made up the 6-file blast radius repaired in T-1468.

This task fixes the **emit site** so future task closes don't re-introduce malformed YAML.

## Acceptance Criteria

### Agent
- [x] Fix `update-task.sh` components auto-populate so it deletes any block-style `  - item` continuation lines that follow the `components:` line BEFORE replacing with flow-style `[...]`. Use a python block (already used elsewhere in this file) rather than sed for multi-line awareness.
- [x] Same fix applied to `related_tasks:` if equivalent block-style overwrite exists (audit shows current code: only tags has python; related_tasks has no auto-populate path — confirm this and document).
- [x] Bats regression test: synthesize a task file with block-style `components:\n  - X\n  - Y\n`, run the auto-populate code path, assert `python3 -c "import yaml; yaml.safe_load(open(f))"` succeeds AND output is valid flow-style with no orphan `- ` lines.
- [x] Verification on existing fixed files: re-run `python3 yaml.safe_load` over all .tasks/active/ + .tasks/completed/ — zero parse errors.
- [x] No regression: `bats tests/unit/*update*` passes.

### Human

(none — purely structural/regression work, no UX surface)

## Verification

# Bats regression for the new test
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/update_task_yaml_components_emit.bats >/dev/null
# All existing update-task tests still pass
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/update_task_components_lookup.bats tests/unit/update_task_episodic_gen.bats tests/unit/update_task_verification.bats tests/unit/update_task_yaml_components_emit.bats >/dev/null
# All task files parse as valid YAML
cd /opt/999-Agentic-Engineering-Framework && python3 tests/scripts/yaml_parse_all_tasks.py

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

### 2026-04-25T19:21:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1469-symptom-b-fix--create-taskshupdate-tasks.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d524a416
- **Timestamp:** 2026-06-02T14:57:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/update_task_yaml_components_emit.bats >/dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/update_task_components_lookup.bats tests/unit/update_task_episodic_gen.bats tests/unit/update_task_verification.bats tests/unit/update_task`
### 2026-04-25T19:27:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
