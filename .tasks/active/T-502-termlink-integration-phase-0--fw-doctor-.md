---
id: T-502
name: "TermLink integration Phase 0 — fw doctor check, agents/termlink/, fw route, CLAUDE.md"
description: >
  Integrate TermLink (cross-terminal session communication) into the framework as an optional
  external tool. Phase 0: fw doctor check, agents/termlink/ (AGENT.md + termlink.sh wrapper),
  fw termlink route, CLAUDE.md section.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [termlink, integration, phase-0]
components: [bin/fw, agents/termlink/termlink.sh, agents/termlink/AGENT.md, CLAUDE.md]
related_tasks: []
created: 2026-03-15T23:31:23Z
last_update: 2026-03-15T23:31:23Z
date_finished: null
---

# T-502: TermLink integration Phase 0 — fw doctor check, agents/termlink/, fw route, CLAUDE.md

## Context

TermLink is a cross-terminal session communication system (Rust binary, 30+ CLI commands, JSON output).
Framework integrates it as an optional external tool for self-testing, parallel dispatch, remote control.
Phase 0 is foundation only — doctor check, agent wrapper, fw route, CLAUDE.md docs.

## Acceptance Criteria

### Agent
- [x] `fw doctor` checks for TermLink (WARN not FAIL, includes install hint)
- [x] `agents/termlink/AGENT.md` exists with primitives table and usage guidance
- [x] `agents/termlink/termlink.sh` implements: check, spawn, exec, status, cleanup, dispatch, wait, result
- [x] `fw termlink` routes to `agents/termlink/termlink.sh`
- [x] `fw help` lists termlink command
- [x] CLAUDE.md has TermLink section with primitives, budget rule, cleanup rule

### Human
- [ ] [RUBBER-STAMP] Run `fw doctor` and verify TermLink check appears
  **Steps:**
  1. Run `fw doctor` in framework repo
  2. Look for TermLink line (OK if installed, WARN if not)
  **Expected:** Line shows "TermLink not installed (cargo install termlink)" or version
  **If not:** Check doctor.sh for the TermLink check block

## Verification

test -f agents/termlink/AGENT.md
test -x agents/termlink/termlink.sh
grep -q "termlink" bin/fw
grep -q "TermLink" CLAUDE.md

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

### 2026-03-15T23:31:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-502-termlink-integration-phase-0--fw-doctor-.md
- **Context:** Initial task creation
