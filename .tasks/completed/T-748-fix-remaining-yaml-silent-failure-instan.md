---
id: T-748
name: "Fix remaining YAML silent-failure instances in Watchtower"
description: >
  Add logging to ~13 yaml.safe_load calls that silently swallow parse errors. Addresses
  R-018 and R-024 concerns.

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-30T00:00:16Z
last_update: '2026-06-11T22:24:28Z'
date_finished: 2026-03-30T00:06:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-748: Fix remaining YAML silent-failure instances in Watchtower

## Context

T-745 fixed 4 crash-risk yaml.safe_load calls (no try/except at all). This task addresses the remaining ~13 instances that have try/except but silently swallow errors without logging. Addresses R-018 and R-024 concerns.

## Acceptance Criteria

### Agent
- [x] All yaml.safe_load except blocks in web/ log a warning with file path and error
- [x] No new imports break existing functionality (Watchtower smoke test passes)
- [x] Each modified file has `import logging` and a module-level logger

## Verification

python3 -c "from web.config import Config; print('config ok')"
python3 -c "from web.blueprints.session import bp; print('session ok')"
python3 -c "from web.blueprints.enforcement import bp; print('enforcement ok')"
python3 -c "from web.blueprints.cron import bp; print('cron ok')"
python3 -c "from web.blueprints.cockpit import bp; print('cockpit ok')"
python3 -c "from web.blueprints.docs import bp; print('docs ok')"
python3 -c "from web.blueprints.discoveries import bp; print('discoveries ok')"
python3 -c "from web.search_utils import aggregate_tags; print('search_utils ok')"
python3 -c "from web.metrics_history import load_entries; print('metrics_history ok')"
curl -sf http://localhost:3000/ > /dev/null

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

### 2026-03-30T00:00:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-748-fix-remaining-yaml-silent-failure-instan.md
- **Context:** Initial task creation

### 2026-03-30T00:06:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15039b33
- **Timestamp:** 2026-06-02T15:04:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 10
     - evidence: `curl -sf http://localhost:3000/ > /dev/null`
