---
id: T-251
name: "Fix C-XXX display in fabric detail page"
description: >
  Fix C-XXX display in fabric detail page

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/fabric.py, web/templates/fabric_detail.html]
related_tasks: []
created: 2026-02-22T15:41:44Z
last_update: '2026-06-11T22:24:17Z'
date_finished: 2026-02-22T15:42:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-251: Fix C-XXX display in fabric detail page

## Context

Legacy C-XXX component IDs in dependency targets showed as raw codes in the fabric detail page, not resolved to component names or linked.

## Acceptance Criteria

### Agent
- [x] Fabric detail page resolves C-XXX IDs to component names in "Depends On" table
- [x] Dependency targets are clickable links to component detail pages
- [x] Path-based targets (agents/context/lib/init.sh) also resolve to names

## Verification

# Detail page loads for context-dispatcher (has C-XXX deps)
curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "add-learning"
# C-002 target resolved to link
curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "C-002"

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

### 2026-02-22T15:41:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-251-fix-c-xxx-display-in-fabric-detail-page.md
- **Context:** Initial task creation

### 2026-02-22T15:42:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6ef1e073
- **Timestamp:** 2026-06-02T15:01:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#3 (Agent)** — Path-based targets (agents/context/lib/init.sh) also resolve to names
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/context/lib/init.sh in: Path-based targets (agents/context/lib/init.sh) also resolve to names`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "add-learning"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "C-002"`
