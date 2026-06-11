---
id: T-588
name: "Declarative status transition rules — compiled ACL pattern for task state machine"
description: >
  Currently update-task.sh has inline case/esac logic for allowed status transitions.
  OpenClaw compiles declarative scope groups to O(1) Map lookup at startup (method-scopes.ts,
  20 LOC compilation). Adopt: declare allowed transitions in status-transitions.yaml,
  compile to lookup, validate in update-task.sh. Benefits: visible rules (anyone can
  read YAML), verifiable (fw doctor validates no orphaned states), extensible (edit
  YAML not bash), auditable (Watchtower displays state machine). Connects to T-511
  governance.yaml (another governance declaration). Implementation language pending
  T-586. Research source: /opt/openclaw-evaluation/.context/working/round2-T-022.md
  (Pattern 4, rated 5 stars directly adoptable). OpenClaw source: src/gateway/method-scopes.ts.
  Related: T-586 (language strategy), T-511 (governance.yaml), agents/task-create/update-task.sh
  (current inline logic).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:35:28Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-28T12:30:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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

# T-588: Declarative status transition rules — compiled ACL pattern for task state machine

## Context

Currently `lib/enums.sh` declares status transitions as a bash array (`VALID_TRANSITIONS`) with O(n) linear scan via `is_valid_transition()`. The task description (OpenClaw Pattern 4) proposes externalizing to YAML and compiling to O(1) lookup. Precedent: `governance.yaml` already declares operation classes as machine-readable YAML. Related: T-511 (governance.yaml), T-586 (language strategy — may influence whether compilation is bash or Python).

Key files:
- `lib/enums.sh` — current transition definitions (lines 28-39) and validation functions (lines 64-71)
- `agents/task-create/update-task.sh` — consumer: calls `is_valid_transition()` and `valid_transitions_for()`
- `.context/project/governance.yaml` — precedent for declarative governance YAML

## Acceptance Criteria

### Agent
- [x] A `status-transitions.yaml` file exists declaring all valid statuses, legacy statuses, and allowed transitions in human-readable YAML (no bash syntax)
- [x] `lib/enums.sh` reads `status-transitions.yaml` at source-time and populates an associative array for O(1) transition lookup (replaces the linear `VALID_TRANSITIONS` array scan)
- [x] `is_valid_transition()`, `valid_transitions_for()`, `is_valid_status()`, and `is_recognized_status()` continue to work with identical behavior (backward compatible — no callers need changes)
- [x] `fw doctor` includes a check that `status-transitions.yaml` has no orphaned states (states in transitions not in the statuses list) and no unreachable states (statuses with no inbound or outbound transition)
- [x] All 8 existing transitions from `lib/enums.sh` are faithfully represented in the YAML file (including the 2 legacy-compat transitions)

## Verification

# YAML file parses correctly
python3 -c "import yaml; d=yaml.safe_load(open('status-transitions.yaml')); assert 'transitions' in d or 'statuses' in d, 'Missing expected keys'"
# Backward compat: valid transition still works
cd /opt/999-Agentic-Engineering-Framework && source lib/enums.sh && is_valid_transition "captured" "started-work"
# Backward compat: invalid transition still rejected
cd /opt/999-Agentic-Engineering-Framework && source lib/enums.sh && ! is_valid_transition "captured" "work-completed"
# fw doctor passes
cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor

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

### 2026-03-23T21:35:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-588-declarative-status-transition-rules--com.md
- **Context:** Initial task creation

### 2026-03-28T12:28:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T12:30:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-93f26053
- **Timestamp:** 2026-06-02T15:03:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
