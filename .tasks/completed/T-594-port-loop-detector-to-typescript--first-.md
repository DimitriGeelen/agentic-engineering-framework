---
id: T-594
name: "Port loop detector to TypeScript — first real TS hook component"
description: >
  Port the T-586 Phase 2 prototype (docs/spikes/T-586-loop-detect-ts/loop-detect.ts, 261 LOC) into lib/ts/src/loop-detect.ts as the first production TS component. Wire as PostToolUse hook in settings.json template. Compile via fw build. 3 detectors: generic_repeat, ping_pong, no_progress. Uses shared state module from T-592 scaffold. Replaces/supersedes T-578 inception (loop detection) — that inception's question is answered by T-586 GO decision. Depends on T-592 (scaffold). Reference: docs/reports/T-586-prototype-comparison.md, docs/spikes/T-586-loop-detect-ts/.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [hooks, typescript, T-586]
components: []
related_tasks: [T-586, T-592, T-578]
created: 2026-03-23T23:00:46Z
last_update: 2026-04-25T14:11:46Z
date_finished: 2026-03-24T06:35:43Z
---

# T-594: Port loop detector to TypeScript — first real TS hook component

## Context

First production TypeScript hook. The prototype proved TS is 2x faster (28ms vs 54ms) and immune to shell escaping. This task promotes the spike from `docs/spikes/` to `lib/ts/src/` as a real framework component.

Supersedes T-578 inception (loop detection) — that inception's question ("should we build loop detection?") is answered by T-586 GO decision + this task's prototype evidence.

Prototype: `docs/spikes/T-586-loop-detect-ts/loop-detect.ts` (261 LOC, 3 detectors)
Benchmark: `docs/reports/T-586-prototype-comparison.md`
OpenClaw reference: `/opt/openclaw-evaluation/src/agents/tool-loop-detection.ts` (624 LOC)

Depends on: T-592 (scaffold — lib/ts/ infrastructure must exist)

## Acceptance Criteria

### Agent
- [x] `lib/ts/src/loop-detect.ts` exists (moved from spike, adapted for lib/ts/ structure)
- [x] Compiles to `lib/ts/dist/loop-detect.js` via `fw build` (5.7KB bundle)
- [x] 3 detectors: generic_repeat, ping_pong, no_progress
- [x] State persisted in `.context/working/.loop-detect.json`
- [x] PostToolUse hook format: reads JSON stdin, outputs `additionalContext` on stderr
- [x] Warning at 5 identical calls (exit 0 + stderr message) — verified at call 6
- [x] Block at 10 identical calls (exit 2 + stderr message) — verified at call 11
- [x] Handles edge cases: empty input, corrupt state, missing state dir (exit 0 = fail open)
- [x] Shell escaping test passes: input containing `'''` and `"` processes correctly
- [x] Hook registered in `lib/init.sh` settings.json template (PostToolUse section)
- [x] Execution time <35ms per invocation (benchmarked: 20ms compiled JS)
- [x] `fw doctor` validates hook script exists (shows "2 source(s)" in TS build check)

<!-- T-1462: rubber-stamp converted to mechanical verification.
     Original Steps required an interactive Claude Code session to repeat a failing call 6 times;
     can be simulated mechanically by piping the same hook payload to the dist JS in a tmp PROJECT_ROOT. -->

## Verification

# Source exists
test -f lib/ts/src/loop-detect.ts
# Compiles
bash lib/build.sh
test -f lib/ts/dist/loop-detect.js
# Mechanical loop-detect dogfood: 6 identical hook payloads in a fresh PROJECT_ROOT should produce
# a "called 5 times" warning on iteration 6 (the 6th call observes the running count of 5).
bash -c 'TMP=$(mktemp -d); mkdir -p "$TMP/.context/working"; SCRIPT="$PWD/lib/ts/dist/loop-detect.js"; for i in 1 2 3 4 5 6; do OUT=$(echo '"'"'{"tool_name":"Read","tool_input":{"file_path":"/nonexistent"}}'"'"' | (cd "$TMP" && node "$SCRIPT") 2>&1); done; rc=1; echo "$OUT" | grep -q "additionalContext.*WARNING" && rc=0; rm -rf "$TMP"; exit $rc'
# Runs without error on normal input
echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/t.txt"},"tool_result":"ok"}' | node lib/ts/dist/loop-detect.js
# Handles empty input gracefully
echo "" | node lib/ts/dist/loop-detect.js

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

### 2026-03-23T23:00:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-594-port-loop-detector-to-typescript--first-.md
- **Context:** Initial task creation

### 2026-03-24T06:32:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T06:35:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
