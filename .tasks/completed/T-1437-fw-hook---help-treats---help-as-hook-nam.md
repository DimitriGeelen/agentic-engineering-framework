---
id: T-1437
name: "fw hook --help treats --help as hook name and logs spurious missing-hook crash"
description: >
  fw hook --help treats --help as hook name and logs spurious missing-hook crash

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T16:43:38Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T16:45:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1437: fw hook --help treats --help as hook name and logs spurious missing-hook crash

## Context

The `fw hook` subcommand (bin/fw:3906) takes `$1` as the hook name and execs
`agents/context/${name}.sh`. When a user runs `fw hook --help`, `_hook_name`
is set to `--help`, the script path is `agents/context/--help.sh`, which
doesn't exist — so the missing-hook branch fires, logs a crash to
`.context/working/.hook-crashes.log`, and exits 0.

Evidence: `.context/working/.hook-crashes.log` line 20 (today):
  2026-04-24T15:43:26Z missing-hook --help script=.../agents/context/--help.sh

Root cause: `fw hook` has no `--help` / `-h` handling. Any argument starting
with `-` is treated as a potential hook name.

Fix: when `$1` is `--help` or `-h`, print the existing usage+available-hooks
block (already emitted when `$1` is empty, line 3908-3913) and exit 0.

## Acceptance Criteria

### Agent
- [x] `fw hook --help` prints usage + available hooks list and exits 0
- [x] `fw hook -h` prints same (alias)
- [x] `fw hook --help` does NOT write to `.context/working/.hook-crashes.log`
- [x] `fw hook <real-hook-name>` still works (not regressed)
- [x] Vendored copy `.agentic-framework/bin/fw` stays in sync (L-257)

## Verification

OUT=$(bin/fw hook --help 2>&1); echo "$OUT" | grep -q "Usage: fw hook"
OUT=$(bin/fw hook --help 2>&1); echo "$OUT" | grep -q "Available hooks:"
OUT=$(bin/fw hook -h 2>&1); echo "$OUT" | grep -q "Usage: fw hook"
bash -c 'B=$(wc -l < .context/working/.hook-crashes.log); bin/fw hook --help >/dev/null 2>&1; bin/fw hook -h >/dev/null 2>&1; A=$(wc -l < .context/working/.hook-crashes.log); test "$B" = "$A"'
bash -c 'bin/fw hook check-active-task </dev/null >/dev/null 2>&1; rc=$?; test $rc -eq 0 -o $rc -eq 2'
diff -q bin/fw .agentic-framework/bin/fw >/dev/null

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

### 2026-04-24T16:43:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1437-fw-hook---help-treats---help-as-hook-nam.md
- **Context:** Initial task creation

### 2026-04-24T16:45:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-73087386
- **Timestamp:** 2026-06-02T14:57:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 6
     - evidence: `diff -q bin/fw .agentic-framework/bin/fw >/dev/null`
