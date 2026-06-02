---
id: T-575
name: "PICKUP-004: Init fails to detect upstream_repo for non-GitHub clones"
description: >
  From 150-skills-manager via TermLink. MEDIUM. Three nested github.com gates in init.sh reject all non-GitHub remotes. upstream_repo silently missing, breaks fw update. RCA: /opt/150-skills-manager/.context/handovers/rca-004-init-upstream-repo.md. Pickup: /opt/150-skills-manager/.context/handovers/pickup-004-init-upstream-repo.md. Learning: L-008.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T20:58:38Z
last_update: 2026-03-24T11:52:41Z
date_finished: 2026-03-24T11:52:41Z
---

# T-575: PICKUP-004: Init fails to detect upstream_repo for non-GitHub clones

## Context

Three `github.com` gates in `lib/init.sh` reject all non-GitHub remotes. `upstream_repo` silently missing, breaks `fw update`. From 150-skills-manager via TermLink.

## Acceptance Criteria

### Agent
- [x] `upstream_repo` detection accepts any git remote URL (not just GitHub)
- [x] GitHub URLs still extract owner/repo correctly
- [x] Non-GitHub URLs stored as full URL (no owner/repo extraction)
- [x] Vendored copy synced

## Verification

grep -q "upstream_repo" lib/init.sh

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

### 2026-03-23T20:58:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-575-pickup-004-init-fails-to-detect-upstream.md
- **Context:** Initial task creation

### 2026-03-24T11:52:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T11:52:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-902b5d68
- **Timestamp:** 2026-06-02T15:03:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
