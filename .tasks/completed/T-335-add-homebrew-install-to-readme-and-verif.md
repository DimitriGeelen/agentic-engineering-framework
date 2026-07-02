---
id: T-335
name: "Add Homebrew install to README and verify tap documentation"
description: >
  The launch article (T-329) and Homebrew tap (T-330) advertise `brew tap DimitriGeelen/agentic-fw
  && brew install fw`
  but the README Quickstart only shows the curl install. Add Homebrew as an install
  option in the README.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [README.md]
related_tasks: [T-329, T-330]
created: 2026-03-06T22:12:20Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-06T22:14:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
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

# T-335: Add Homebrew install to README and verify tap documentation

## Context

Article (T-329) and tap repo (T-330) advertise Homebrew install, but README only shows curl. Gap discovered during T-329 article review.

## Acceptance Criteria

### Agent
- [x] README Quickstart includes Homebrew install option (`brew tap` + `brew install fw`)
- [x] Homebrew and curl install are both present as alternatives
- [x] README task count matches article (312, not 325)

### Human
- [x] `brew tap DimitriGeelen/agentic-fw && brew install fw` verified on macOS

## Verification

grep -q "brew tap" README.md
grep -q "brew install fw" README.md
grep -q "curl -fsSL" README.md

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

### 2026-03-06T22:12:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-335-add-homebrew-install-to-readme-and-verif.md
- **Context:** Initial task creation

### 2026-03-06T22:14:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-96341a34
- **Timestamp:** 2026-06-02T15:02:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **external-publish** (high) — External publish or release
     - matched: `brew tap`
