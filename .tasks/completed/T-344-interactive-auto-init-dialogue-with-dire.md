---
id: T-344
name: "Interactive auto-init dialogue with directory and provider selection"
description: >
  Replace the simple Y/n auto-init prompt in bin/fw with a 2-question guided dialogue:
  (1) where to initialize (git root vs cwd vs custom), (2) which provider (claude/cursor/generic).
  Uses detect-and-confirm pattern — smart defaults, Enter-through, non-TTY safe.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [cli, ux, onboarding]
components: [bin/fw]
related_tasks: [T-343, T-294, T-304]
created: 2026-03-08T11:20:14Z
last_update: '2026-08-16T22:25:28Z'
date_finished: 2026-03-08T12:30:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=2 (body:default-change); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=2 (body:default-change); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-344: Interactive auto-init dialogue with directory and provider selection

## Context

Replaces T-343's simple Y/n auto-init with a guided 2-question dialogue. Research from 3 agents:
git root detection edge cases, current init flow gaps, CLI UX best practices (cargo/gh/npm patterns).

Design: detect-and-confirm pattern. Detect git root and cwd, present numbered choices with smart
defaults, Enter-through gets the right answer. Non-TTY falls through silently with defaults.

## Acceptance Criteria

### Agent
- [x] Auto-init shows numbered directory choices (git root if different from cwd, cwd, custom)
- [x] Auto-init prompts for provider (claude default, cursor, generic)
- [x] Enter-through on both prompts selects sensible defaults (git root or cwd + claude)
- [x] Non-TTY environments skip dialogue and use defaults silently
- [x] Commands init/help/version/-h/-v/--help/--version are still excluded from prompt
- [x] `do_init` called with correct `--provider` flag based on selection
- [x] Re-exec of original command works after init completes

### Human
- [x] [REVIEW] Dialogue flow feels natural in a real terminal
  **Steps:**
  1. `mkdir /tmp/test-init-dialogue && cd /tmp/test-init-dialogue && git init`
  2. Run `fw doctor`
  3. Walk through both prompts (directory choice, provider choice)
  4. Verify init completes and doctor re-runs
  5. `rm -rf /tmp/test-init-dialogue`
  **Expected:** 2 clear prompts with numbered choices, Enter defaults work, init succeeds
  **If not:** Note which prompt was confusing or which default was wrong

## Verification

# Auto-init block exists with directory detection
grep -q "git.*rev-parse.*show-toplevel" bin/fw
# Provider prompt exists
grep -q "provider" bin/fw && grep -q "Claude Code" bin/fw && grep -q "Cursor" bin/fw
# Non-TTY guard exists
grep -q "\-t 0\|isatty\|/dev/tty" bin/fw
# Excluded commands still work
grep -q '"init"' bin/fw

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

### 2026-03-08T11:20:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-344-interactive-auto-init-dialogue-with-dire.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61d83ae7
- **Timestamp:** 2026-06-02T15:02:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
