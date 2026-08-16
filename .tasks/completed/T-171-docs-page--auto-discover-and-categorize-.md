---
id: T-171
name: "Docs page — auto-discover and categorize project docs"
description: >
  Docs page — auto-discover and categorize project docs

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: []
related_tasks: []
created: 2026-02-18T18:06:27Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-02-18T18:08:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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
  - ts: '2026-08-16T22:24:42Z'
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

# T-171: Docs page — auto-discover and categorize project docs

## Context

Build task from T-133 inception (GO). Expand Docs page to auto-discover docs from standard locations.

## Acceptance Criteria

- [x] Auto-discover docs from root, docs/, docs/plans/, agents/*/AGENT.md
- [x] Categorize into Governance, Design, Agents, Project groups
- [x] CLAUDE.md and FRAMEWORK.md appear as top-level governance docs
- [x] Subdirectory docs render correctly via -- path separator
- [x] Grid layout shows all categories on one page

## Verification

curl -sf http://localhost:3000/project | grep -q "Governance"
curl -sf http://localhost:3000/project | grep -q "Design"
curl -sf http://localhost:3000/project | grep -q "Agents"
curl -sf http://localhost:3000/project/CLAUDE | grep -q "Core Principle"
curl -sf http://localhost:3000/project/docs--cycle2-protocol | grep -q "html"
curl -sf http://localhost:3000/project/agents--audit--AGENT | grep -q "html"

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

### 2026-02-18T18:06:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-171-docs-page--auto-discover-and-categorize-.md
- **Context:** Initial task creation

### 2026-02-18T18:08:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6b8ce9a6
- **Timestamp:** 2026-06-02T14:59:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 6

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/project | grep -q "Governance"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/project | grep -q "Design"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/project | grep -q "Agents"`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/project/CLAUDE | grep -q "Core Principle"`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `curl -sf http://localhost:3000/project/docs--cycle2-protocol | grep -q "html"`
  6. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `curl -sf http://localhost:3000/project/agents--audit--AGENT | grep -q "html"`
