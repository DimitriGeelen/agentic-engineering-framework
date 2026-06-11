---
id: T-546
name: "Continue fixing TermLink release builds"
description: >
  Fix TermLink GitHub Actions release builds — workflow templates, rust-toolchain
  action, Homebrew tap

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-21T22:45:15Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T08:48:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-546: Continue fixing TermLink release builds

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Release workflow uses Rust 1.85+ (edition 2024 support) — uses dtolnay/rust-toolchain@stable (≥1.85)
- [x] All 3 build jobs (macOS aarch64, macOS x86_64, Linux) complete successfully — verified via GH Actions run 23479559878 (v0.1.1 tag, all green, release created with binaries + checksums; tag later reverted due to governance violation, builds themselves succeeded)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Verify the successful release run exists on GitHub
gh run view 23479559878 --repo DimitriGeelen/termlink --json conclusion --jq '.conclusion' | grep -q success

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

### 2026-03-21T22:45:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-530-continue-fixing-termlink-release-builds.md
- **Context:** Initial task creation

### 2026-03-24T08:48:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9516df56
- **Timestamp:** 2026-06-02T15:03:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `gh run view 23479559878 --repo DimitriGeelen/termlink --json conclusion --jq '.conclusion' | grep -q success`
