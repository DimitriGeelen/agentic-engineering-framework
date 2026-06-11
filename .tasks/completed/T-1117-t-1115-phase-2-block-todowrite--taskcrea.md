---
id: T-1117
name: "T-1115 Phase 2: block TodoWrite + TaskCreate via PreToolUse hook (Level 1)"
description: >
  T-1115 Phase 2: block TodoWrite + TaskCreate via PreToolUse hook (Level 1)

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T06:52:55Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T09:07:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1117: T-1115 Phase 2: block TodoWrite + TaskCreate via PreToolUse hook (Level 1)

## Context

Phase 2 of T-1115 GO decision. T-1116 TermLink E2E spike confirmed:
PreToolUse fires on `TodoWrite` (the tool backing Claude Code's built-in
todo/task UI). Level 1 = block via exit 2 with redirect to `bin/fw work-on`.
Pattern: `block-plan-mode.sh` (T-242).

Research: `docs/reports/T-1115-anthropic-task-tool-prehook.md`
Spike result: T-1116 Updates (2026-04-12T06:50:18Z)

## Acceptance Criteria

### Agent
- [x] `agents/context/block-task-tools.sh` exists, executable, exits 2,
      stderr contains redirect message to `bin/fw work-on`
- [x] `tests/unit/block_task_tools.bats` passes with 7 test cases
      (exit code, stderr message, stdin ignored, TodoWrite payload, fw hook route)
- [x] CLAUDE.md updated with §Built-in Task Tool Ban referencing the hook
- [x] Research artifact updated with post-spike findings
- [x] `fw doctor` passes (no regressions)
- [x] `bin/fw hook` help text lists `block-task-tools`

### Human
- [x] [RUBBER-STAMP] Merge PreToolUse entry into `.claude/settings.json`
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && jq '.hooks.PreToolUse += [{"matcher":"TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet","hooks":[{"type":"command","command":"bin/fw hook block-task-tools"}]}]' .claude/settings.json > .claude/settings.json.new && python3 -c "import json; json.load(open('.claude/settings.json.new'))" && mv .claude/settings.json.new .claude/settings.json`
  2. Restart Claude Code (hooks snapshot at session start)
  3. `cd /opt/999-Agentic-Engineering-Framework && python3 -c "import json; d=json.load(open('.claude/settings.json')); print([h['matcher'] for h in d['hooks']['PreToolUse']])"` — verify the matcher is present
  **Expected:** PreToolUse array contains a matcher for `TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet`
  **If not:** Check if jq produced valid JSON; restore from git: `git checkout .claude/settings.json`

## Verification

test -x agents/context/block-task-tools.sh
echo '{}' | agents/context/block-task-tools.sh 2>/dev/null; test $? -eq 2
bash -c 'agents/context/block-task-tools.sh 2>&1 | grep -q "fw work-on"'
python3 -c "import json; d=json.load(open('.claude/settings.json')); assert any('TodoWrite' in h.get('matcher','') for h in d['hooks']['PreToolUse'])"
bats tests/unit/block_task_tools.bats

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

### 2026-04-12T06:52:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1117-t-1115-phase-2-block-todowrite--taskcrea.md
- **Context:** Initial task creation

### 2026-04-12T07:15:00Z — E2E block verification [TermLink dispatch]
- **Method:** `fw termlink dispatch --name t1117-block-e2e` with block hook
  temporarily registered in settings.json
- **Result:** CONFIRMED — worker attempted TodoWrite, hook returned exit 2,
  tool call was completely blocked, redirect message displayed to agent.
- **Full chain verified:** PreToolUse fires → block-task-tools.sh exits 2 →
  TodoWrite call blocked → agent sees "Use bin/fw work-on" message
- **Settings.json restored** after test (B-005 protected — human merges final)

### 2026-04-12T09:07:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e995f5fa
- **Timestamp:** 2026-06-02T14:55:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c 'agents/context/block-task-tools.sh 2>&1 | grep -q "fw work-on"'`
