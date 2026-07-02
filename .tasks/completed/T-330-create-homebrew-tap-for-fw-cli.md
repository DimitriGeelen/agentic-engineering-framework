---
id: T-330
name: "Create Homebrew Tap for fw CLI"
description: >
  Create homebrew-agentic-fw tap repo with Ruby formula pointing at release tarball.
  Enables: brew install DimitriGeelen/tap/fw. Requires v1.0.0 release tag first. Ref:
  docs/reports/T-327-visibility-strategy.md

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-05T01:12:33Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-05T01:34:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
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

# T-330: Create Homebrew Tap for fw CLI

## Context

Homebrew tap for standard CLI distribution. Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [x] GitHub repo DimitriGeelen/homebrew-agentic-fw created
- [x] Ruby formula (Formula/fw.rb) with correct SHA256 and tarball URL
- [x] README with install/usage/update/uninstall instructions

### Human
- [x] `brew tap DimitriGeelen/agentic-fw && brew install fw` works on a macOS machine

## Verification

# Verify the tap repo exists on GitHub
gh repo view DimitriGeelen/homebrew-agentic-fw --json name -q .name

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

### 2026-03-05T01:12:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-330-create-homebrew-tap-for-fw-cli.md
- **Context:** Initial task creation

### 2026-03-05T01:31:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-05T01:34:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8d6b6a7e
- **Timestamp:** 2026-06-02T15:02:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Ruby formula (Formula/fw.rb) with correct SHA256 and tarball URL
  - **AC-verify-mismatch** (narrow, heuristic) — `path=Formula/fw.rb in: Ruby formula (Formula/fw.rb) with correct SHA256 and tarball URL`
