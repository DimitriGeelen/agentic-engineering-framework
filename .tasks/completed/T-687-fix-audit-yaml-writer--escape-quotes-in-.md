---
id: T-687
name: "Fix audit YAML writer — escape quotes in findings to prevent parse errors"
description: >
  Fix audit YAML writer — escape quotes in findings to prevent parse errors

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: []
created: 2026-03-28T22:55:10Z
last_update: '2026-08-16T22:25:37Z'
date_finished: 2026-03-28T22:56:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
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
  - ts: '2026-08-16T22:25:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-687: Fix audit YAML writer — escape quotes in findings to prevent parse errors

## Context

Audit YAML output had broken strings — embedded double quotes in mitigation text caused YAML parse errors (e.g., `fw fix-learned T-XXX "description"` inside a YAML quoted string). Fixed the source string and hardened the YAML writer to properly escape backslashes and quotes. Also fixed the existing broken file (2026-03-09.yaml). Related: R-018 (invalid YAML data disappears without error).

## Acceptance Criteria

### Agent
- [x] Fixed broken YAML in `.context/audits/2026-03-09.yaml` (unescaped quotes)
- [x] Changed `warn()` argument to use single quotes instead of embedded double quotes
- [x] Hardened YAML writer to escape backslashes then double quotes in finding strings
- [x] All existing audit YAML files parse without errors

## Verification

# All audit YAML files parse correctly
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('.context/audits/2026-*.yaml')]"
# Writer has proper escaping
grep -q 'escape backslashes first' agents/audit/audit.sh

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

### 2026-03-28T22:55:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-687-fix-audit-yaml-writer--escape-quotes-in-.md
- **Context:** Initial task creation

### 2026-03-28T22:56:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff67b8e7
- **Timestamp:** 2026-06-02T15:04:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Fixed broken YAML in `.context/audits/2026-03-09.yaml` (unescaped quotes)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/2026-03-09.yaml in: Fixed broken YAML in `.context/audits/2026-03-09.yaml` (unescaped quotes)`
