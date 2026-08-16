---
id: T-572
name: "PICKUP-001: Path isolation failures in multi-project environments"
description: >
  From 150-skills-manager via TermLink. CRITICAL. resolve_framework() wrong priority
  order + PATH pollution + vendor contamination. Consumer patches validated. RCA:
  /opt/150-skills-manager/.context/project/RCA-2026-0323-path-isolation.md. Pickup:
  /opt/150-skills-manager/.context/handovers/pickup-001-path-isolation.md. Learnings:
  L-003, L-004, L-009, L-012.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T20:58:32Z
last_update: '2026-08-16T22:25:34Z'
date_finished: 2026-03-24T09:02:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-572: PICKUP-001: Path isolation failures in multi-project environments

## Context

Consumer project (150-skills-manager) reported path isolation failures. Upstream investigation confirms all three G-021 contamination points already fixed: (1) init.sh uses portable `.agentic-framework/bin/fw` paths, (2) .framework.yaml no longer has framework_path, (3) CLAUDE.md template has no FRAMEWORK_ROOT placeholder. fw doctor validates hook paths. Dead `__FRAMEWORK_ROOT__` sed substitution in init.sh cleaned up.

## Acceptance Criteria

### Agent
- [x] No `__FRAMEWORK_ROOT__` placeholder in consumer CLAUDE.md template
- [x] init.sh settings.json heredoc uses quoted delimiter (no variable expansion)
- [x] fw doctor hook validation reports all hooks portable (11 hooks)
- [x] Dead `__FRAMEWORK_ROOT__` sed substitution removed from init.sh

## Verification

# No hardcoded absolute paths in consumer hook template
grep -c 'agentic-framework/bin/fw' lib/init.sh | grep -q '[1-9]'
# Quoted heredoc prevents variable expansion
grep -q "^SJSON$" lib/init.sh
# No FRAMEWORK_ROOT placeholder in template (grep exits 1 = not found = good)
grep -q '__FRAMEWORK_ROOT__' lib/templates/claude-project.md && exit 1 || true
# Doctor hook validation passes (capture to file to avoid SIGPIPE)
fw doctor > /tmp/fw-doctor-t572.txt 2>&1 || true; grep -q "hooks, all portable" /tmp/fw-doctor-t572.txt

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

### 2026-03-23T20:58:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-572-pickup-001-path-isolation-failures-in-mu.md
- **Context:** Initial task creation

### 2026-03-24T08:58:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T09:02:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fd396234
- **Timestamp:** 2026-06-02T15:03:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -c 'agentic-framework/bin/fw' lib/init.sh | grep -q '[1-9]'`
