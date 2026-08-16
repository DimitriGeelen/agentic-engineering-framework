---
id: T-1116
name: "T-1115 Phase 1: TaskCreate hook probe script + fresh-session verification checklist"
description: >
  T-1115 Phase 1: TaskCreate hook probe script + fresh-session verification checklist

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T22:41:04Z
last_update: '2026-08-16T22:24:23Z'
date_finished: 2026-04-11T22:43:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1116: T-1115 Phase 1: TaskCreate hook probe script + fresh-session verification checklist

## Context

Phase 1 of T-1115 GO decision. Delivers a probe script + fresh-session
verification checklist for the must-verify spike A1: does Claude Code
fire `PreToolUse` on `TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet`?
Does NOT modify live `.claude/settings.json` — all artifacts live in
`tests/spikes/` and are only activated manually by the human before
restarting Claude Code in a fresh session.

Out of scope for this task (deferred to next session as follow-up):
the fallback CLAUDE.md rule, the PostToolUse scanner, and the Level 1
block hook — all conditional on the spike result.

## Acceptance Criteria

### Agent
- [x] `tests/spikes/taskcreate-hook-probe.sh` exists, executable, logs
      stdin + argv + timestamp + tool name to
      `.context/working/.taskcreate-probe.log`, exits 0.
- [x] `tests/spikes/taskcreate-hook-probe-settings-fragment.json`
      exists with a valid PreToolUse matcher for
      `TaskCreate|TaskUpdate|TaskList|TaskGet` (human merges manually).
- [x] `tests/spikes/taskcreate-hook-probe-README.md` gives a
      copy-pasteable checklist: install fragment, restart Claude Code,
      call TaskList, check the log, report result.
- [x] Probe script smoke-tested locally: `echo '{}' | bash tests/spikes/taskcreate-hook-probe.sh`
      writes a log line and exits 0.

### Human
- [x] [REVIEW] Run the spike in a fresh Claude Code session
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat tests/spikes/taskcreate-hook-probe-README.md` (read the checklist)
  2. Merge `tests/spikes/taskcreate-hook-probe-settings-fragment.json` into `.claude/settings.json` (or read-only: just start a new session from a clone that has the fragment)
  3. Restart Claude Code (exit current session, start fresh with `claude`)
  4. In the fresh session, issue a harmless built-in task tool call (e.g., "please add a TODO item: test spike")
  5. Inspect `.context/working/.taskcreate-probe.log` — is it populated?
  **Expected:** Either the log file contains a line (hooks fire on Task tools — proceed to Phase 2 Level 1 hook implementation) OR the log file is empty/absent (hooks do NOT fire on Task tools — proceed to Phase 2 fallback: CLAUDE.md rule + PostToolUse scanner).
  **If not:** Report which case you got in the T-1116 Updates section, then decide T-1115 accordingly.

## Verification

test -x tests/spikes/taskcreate-hook-probe.sh
test -f tests/spikes/taskcreate-hook-probe-settings-fragment.json
test -f tests/spikes/taskcreate-hook-probe-README.md
bash -c 'echo "{\"tool_name\":\"TaskCreate\",\"tool_input\":{\"subject\":\"test\"}}" | tests/spikes/taskcreate-hook-probe.sh'
test -f .context/working/.taskcreate-probe.log
python3 -c "import json; json.load(open('tests/spikes/taskcreate-hook-probe-settings-fragment.json'))"

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

### 2026-04-11T22:41:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1116-t-1115-phase-1-taskcreate-hook-probe-scr.md
- **Context:** Initial task creation

### 2026-04-11T22:43:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T06:50:18Z — spike-result [TermLink E2E verification]
- **Method:** TermLink dispatch (`fw termlink dispatch --name t1116-spike-2`)
  spawned a fresh `claude -p` worker with the probe hook installed in
  `.claude/settings.json`. Worker called `TodoWrite` once.
- **Result A: CONFIRMED — PreToolUse fires on `TodoWrite`**
- **Critical correction:** The built-in todo/task UI is backed by
  `TodoWrite`, NOT `TaskCreate`. In `-p` mode, TaskCreate does not
  exist — only TodoWrite. The T-1115 matcher must target `TodoWrite`.
- **Probe log entry:**
  ```
  2026-04-12T06:50:18Z pid=3457052 tool_name=TodoWrite
  tool_input={"todos":[{"content":"spike-probe-todowrite","status":"in_progress"}]}
  ```
- **Implication:** Phase 2 Level 1 hook should match `TodoWrite`
  (and optionally `TaskCreate|TaskUpdate` for interactive-mode coverage).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8bab233
- **Timestamp:** 2026-06-02T14:55:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
