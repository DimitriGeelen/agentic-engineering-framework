---
id: T-352
name: "Fix hook path resolution in fw init for Homebrew installs"
description: >
  Fix hook path resolution in fw init for Homebrew installs

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [lib/init.sh]
related_tasks: []
created: 2026-03-08T15:57:48Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-08T15:59:54Z
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

# T-352: Fix hook path resolution in fw init for Homebrew installs

## Context

`_sed_i` function was undefined in `lib/init.sh` — `__FRAMEWORK_ROOT__` and `__PROJECT_ROOT__` placeholders in generated `.claude/settings.json` were never replaced with real paths. Fix: use unquoted heredoc with shell variable expansion instead of post-processing with sed.

## Acceptance Criteria

### Agent
- [x] Generated `.claude/settings.json` contains real absolute paths, not `__FRAMEWORK_ROOT__` placeholders
- [x] `fw doctor` reports "Hook configuration valid" on freshly initialized project

### Human
- [x] [RUBBER-STAMP] Homebrew install + fw init + fw doctor passes on macOS
  **Steps:**
  1. `brew reinstall DimitriGeelen/agentic-fw/fw` (after this version is released)
  2. `mkdir /tmp/test-brew && cd /tmp/test-brew && git init && fw init --provider claude`
  3. `fw doctor`
  **Expected:** No FAIL on hook config, all hooks resolve
  **If not:** Check `.claude/settings.json` for placeholder strings

## Verification

# Test that init generates real paths (no placeholders)
tmpdir=$(mktemp -d) && git init -q "$tmpdir" && fw init "$tmpdir" --provider claude --force >/dev/null 2>&1 && ! grep -q '__FRAMEWORK_ROOT__\|__PROJECT_ROOT__' "$tmpdir/.claude/settings.json" && rm -rf "$tmpdir"

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

### 2026-03-08T15:57:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-352-fix-hook-path-resolution-in-fw-init-for-.md
- **Context:** Initial task creation

### 2026-03-08T15:59:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-833cedaa
- **Timestamp:** 2026-06-02T15:02:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`
