---
id: T-594
name: "Port loop detector to TypeScript — first real TS hook component"
description: >
  Port the T-586 Phase 2 prototype (docs/spikes/T-586-loop-detect-ts/loop-detect.ts, 261 LOC) into lib/ts/src/loop-detect.ts as the first production TS component. Wire as PostToolUse hook in settings.json template. Compile via fw build. 3 detectors: generic_repeat, ping_pong, no_progress. Uses shared state module from T-592 scaffold. Replaces/supersedes T-578 inception (loop detection) — that inception's question is answered by T-586 GO decision. Depends on T-592 (scaffold). Reference: docs/reports/T-586-prototype-comparison.md, docs/spikes/T-586-loop-detect-ts/.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [hooks, typescript, T-586]
components: []
related_tasks: [T-586, T-592, T-578]
created: 2026-03-23T23:00:46Z
last_update: 2026-03-23T23:00:46Z
date_finished: null
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
- [ ] `lib/ts/src/loop-detect.ts` exists (moved from spike, adapted for lib/ts/ structure)
- [ ] Compiles to `lib/ts/dist/loop-detect.js` via `fw build`
- [ ] 3 detectors: generic_repeat, ping_pong, no_progress
- [ ] State persisted in `.context/working/.loop-detect.json`
- [ ] PostToolUse hook format: reads JSON stdin, outputs `additionalContext` on stderr
- [ ] Warning at 5 identical calls (exit 0 + stderr message)
- [ ] Block at 10 identical calls (exit 2 + stderr message)
- [ ] Handles edge cases: empty input, corrupt state, missing state dir (exit 0 = fail open)
- [ ] Shell escaping test passes: input containing `'''` and `"` processes correctly
- [ ] Hook registered in `lib/init.sh` settings.json template (PostToolUse section)
- [ ] Execution time <35ms per invocation (benchmarked, compiled JS)
- [ ] `fw doctor` validates hook script exists

### Human
- [ ] [RUBBER-STAMP] Verify loop detection fires by repeating the same failing command 6+ times
  **Steps:**
  1. Start a Claude Code session in a project with the framework
  2. Intentionally repeat a failing tool call 6 times (e.g., read a non-existent file)
  3. Check stderr or agent response for loop warning message
  **Expected:** Warning appears after 5th identical call
  **If not:** Check `.context/working/.loop-detect.json` for state, verify hook is in settings.json

## Verification

# Source exists
test -f lib/ts/src/loop-detect.ts
# Compiles
bash lib/build.sh
test -f lib/ts/dist/loop-detect.js
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
