---
id: T-516
name: "Tier B E2E tests — 4 agent-level Claude Code governance tests"
description: >
  Write 4 test scripts in tests/e2e/tier-b/ covering: full lifecycle (B1), task gate
  in agent (B2), inception discipline (B3), error handling (B4). Requires API key,
  ~$0.50-1 per scenario. Uses tl-claude.sh + pty inject/output. From T-513 inception
  build task 3.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-17T21:10:37Z
last_update: '2026-06-11T22:24:23Z'
date_finished: 2026-03-17T22:01:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
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

# T-516: Tier B E2E tests — 4 agent-level Claude Code governance tests

## Context

From T-513 inception. Tier B tests spawn Claude Code via TermLink and validate governance behavior with real API calls (~$0.50-1 per scenario). Run manually, not in CI.

## Acceptance Criteria

### Agent
- [x] Test scripts exist in `tests/e2e/tier-b/`
- [x] Scripts syntax-check cleanly (`bash -n`)
- [x] Scripts skip gracefully when ANTHROPIC_API_KEY is unset
- [x] Runner discovers Tier B tests with `--tier b`
- [x] Run `tests/e2e/runner.sh --tier b` and verify at least B1 passes (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

test $(ls tests/e2e/tier-b/test-*.sh 2>/dev/null | wc -l) -ge 2
bash -n tests/e2e/tier-b/test-lifecycle.sh
test -x tests/e2e/runner.sh

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

### 2026-03-17T21:10:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-516-tier-b-e2e-tests--4-agent-level-claude-c.md
- **Context:** Initial task creation

### 2026-03-17T21:59:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-17T22:01:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab16738f
- **Timestamp:** 2026-06-02T15:03:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
