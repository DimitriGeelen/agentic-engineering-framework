---
id: T-632
name: "Watchtower file viewer — clickable links to docs/reports and task files"
description: >
  Watchtower file viewer — clickable links to docs/reports and task files

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-26T22:28:28Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T18:30:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-632: Watchtower file viewer — clickable links to docs/reports and task files

## Context

When the agent references `docs/reports/T-625-global-framework-sync.md`, the human should be able to click a link to read it in Watchtower. Add a `/file/<path>` route that renders project markdown files.

## Acceptance Criteria

### Agent
- [x] `/file/<path>` route serves markdown files rendered as HTML
- [x] Only safe directories viewable (docs/, .tasks/, .context/handovers/, .context/episodic/)
- [x] Path traversal blocked (../../etc/passwd → 404, bin/fw → 404)
- [x] Non-existent files return 404
- [x] Verified with curl against running Watchtower
- [x] Click a file link and verify it renders (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

# Verify /file/ route serves markdown (any running Watchtower port)
grep -q "def file_viewer" web/blueprints/docs.py
curl -sf http://localhost:3000/file/docs/reports/ | grep -q "reports"

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

### 2026-03-26T22:28:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-632-watchtower-file-viewer--clickable-links-.md
- **Context:** Initial task creation

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-27T18:30:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a5243ba3
- **Timestamp:** 2026-06-02T15:04:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/file/docs/reports/ | grep -q "reports"`
