---
id: T-1364
name: "G-053-A: absolute hook paths at fw init/upgrade (eliminate CWD-drift hook-cascade
  class)"
description: >
  G-053-A: absolute hook paths at fw init/upgrade (eliminate CWD-drift hook-cascade
  class)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-009, lib/init.sh, tests/unit/hook_absolute_paths.bats]
related_tasks: []
created: 2026-04-20T19:00:11Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T19:11:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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

# T-1364: G-053-A: absolute hook paths at fw init/upgrade (eliminate CWD-drift hook-cascade class)

## Context

G-053 item A: `.claude/settings.json` currently uses relative `fw` paths (`bin/fw hook X` or `.agentic-framework/bin/fw hook X`). Claude Code resolves these against CWD. When session CWD drifts (test fixtures, subdirectory navigation), hooks fail to locate `fw`, cascade into tool-blocks, and require out-of-band recovery. Defense-in-depth after T-1360 safety net. Fix: emit absolute paths at init/upgrade time since `$target_dir` is already canonicalized via `cd && pwd` in both entry points.

## Acceptance Criteria

### Agent
- [x] `lib/init.sh generate_claude_code_config` emits absolute paths (prefixed with `$dir`)
- [x] Framework's own `.claude/settings.json` regenerated to use absolute paths
- [x] Bats test asserts: generated settings.json has no relative `fw` commands
- [x] All bats tests pass (`fw test unit`)

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

# Shell commands that MUST pass before work-completed. One per line.
# Framework settings.json has NO relative bin/fw hook commands (must be absolute).
! grep -qE '"command": *"bin/fw hook' .claude/settings.json
! grep -qE '"command": *"\.agentic-framework/bin/fw hook' .claude/settings.json
# The absolute path test passes.
bats tests/unit/hook_absolute_paths.bats

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

### 2026-04-20T19:00:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1364-g-053-a-absolute-hook-paths-at-fw-initup.md
- **Context:** Initial task creation

### 2026-04-20T19:11:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-00799e81
- **Timestamp:** 2026-06-02T14:56:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
