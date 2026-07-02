---
id: T-424
name: "Extract lib/tasks.sh and lib/yaml.sh — task lookup and YAML helpers (S6+S7)"
description: >
  S6: Task file lookup duplicated in 4+ files — extract find_task_file(). S7: YAML
  field extraction with grep/sed in 10+ files — extract get_yaml_field() using Python
  yaml.safe_load. Directive scores: S6=6, S7=6. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon: null
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:05Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T10:16:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-424: Extract lib/tasks.sh and lib/yaml.sh — task lookup and YAML helpers (S6+S7)

## Context

Shell task/YAML helpers (S6+S7). See `docs/reports/T-411-refactoring-directive-scoring.md` § SHELL rows S6 (task lookup, 4 files, score 6), S7 (YAML extraction, 10 files, score 6). Depends on T-412 (lib/paths.sh) for consistent sourcing pattern.

## Acceptance Criteria

### Agent
- [x] lib/tasks.sh created with find_task_file(), task_exists(), get_task_name()
- [x] lib/yaml.sh created with get_yaml_field()
- [x] Both sourced via lib/paths.sh chain
- [x] 7 find task file sites updated to use find_task_file()
- [x] 6 YAML extraction sites updated to use get_yaml_field()
- [x] Dead BLUE color references replaced with CYAN across 6 files
- [x] fw doctor, resume, git status, healing, context status all pass

### Human
- [x] [RUBBER-STAMP] Spot-check that healing and context agents work
  **Steps:**
  1. Run `fw healing suggest`
  2. Run `fw context status`
  3. Run `fw resume quick`
  **Expected:** All produce output without errors
  **If not:** Check that lib/tasks.sh and lib/yaml.sh are sourced by lib/paths.sh

## Verification

bash -n lib/tasks.sh
bash -n lib/yaml.sh
grep -q "tasks.sh" lib/paths.sh
grep -q "yaml.sh" lib/paths.sh
# find_task_file works
bash -c 'source lib/paths.sh && find_task_file T-424 | grep -q T-424'
# get_yaml_field works
bash -c 'source lib/paths.sh && f=$(find_task_file T-424) && get_yaml_field "$f" "status" | grep -q work'
# No remaining $BLUE references
! grep -rq '${BLUE}' agents/ lib/
fw doctor 2>&1 | grep -q "All checks passed"

## Decisions

## Updates

### 2026-03-10T21:04:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-424-extract-libtaskssh-and-libyamlsh--task-l.md
- **Context:** Initial task creation

### 2026-03-11T10:11:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T10:16:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c903fda8
- **Timestamp:** 2026-06-02T15:02:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `bash -c 'source lib/paths.sh && find_task_file T-424 | grep -q T-424'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `bash -c 'source lib/paths.sh && f=$(find_task_file T-424) && get_yaml_field "$f" "status" | grep -q work'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `fw doctor 2>&1 | grep -q "All checks passed"`
