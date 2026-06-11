---
id: T-146
name: "Fix G-001: fw init generic provider must wire Claude Code hooks"
description: >
  Fix G-001: fw init generic provider must wire Claude Code hooks

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T10:01:46Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-02-18T10:02:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
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
---

# T-146: Fix G-001: fw init generic provider must wire Claude Code hooks

## Context

G-001: `fw init --provider generic` (the default) skipped `generate_claude_code_config()`, so new projects got no budget-gate, checkpoint, or error-watchdog hooks. See `.context/inbox/2026-02-18-sprechloop-gap-feedback.md`.

## Acceptance Criteria

- [x] `fw init` (generic provider) generates `.claude/settings.json` with all hooks
- [x] `PROJECT_ROOT` in generated hooks points to project dir, not framework
- [x] Unknown provider fallback also wires hooks

## Verification

# Test that generic provider wires hooks in init.sh
grep -q "generate_claude_code_config" lib/init.sh
# Verify generic case has generate_claude_code_config before its ;;
grep -A3 "generic)" lib/init.sh | grep -q "generate_claude_code_config"

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

### 2026-02-18T10:01:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-146-fix-g-001-fw-init-generic-provider-must-.md
- **Context:** Initial task creation

### 2026-02-18T10:02:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b920807e
- **Timestamp:** 2026-06-02T14:57:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (ACs)** — `fw init` (generic provider) generates `.claude/settings.json` with all hooks
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: `fw init` (generic provider) generates `.claude/settings.json` with all hooks`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `grep -A3 "generic)" lib/init.sh | grep -q "generate_claude_code_config"`
