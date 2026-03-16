---
id: T-503
name: "TermLink Phase 0 build — doctor check, agents/termlink/, fw route, CLAUDE.md"
description: >
  Build Phase 0 of TermLink integration. 5 deliverables: fw doctor check (WARN not FAIL),
  agents/termlink/AGENT.md, agents/termlink/termlink.sh (8 subcommands adapted from tl-dispatch.sh),
  fw termlink route, CLAUDE.md section. From T-502 inception GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [termlink, integration, phase-0]
components: [bin/fw, agents/termlink/termlink.sh, agents/termlink/AGENT.md, CLAUDE.md]
related_tasks: [T-502]
created: 2026-03-15T23:58:50Z
last_update: 2026-03-15T23:58:50Z
date_finished: null
---

# T-503: TermLink Phase 0 build — doctor check, agents/termlink/, fw route, CLAUDE.md

## Context

From T-502 inception GO. Spec from TermLink repo T-148. Reference impl: `tl-dispatch.sh`.
Repo: `https://onedev.docker.ring20.geelenandcompany.com/termlink`

## Acceptance Criteria

### Agent
- [x] `fw doctor` checks for TermLink (WARN not FAIL, includes install hint)
- [x] `agents/termlink/AGENT.md` exists with primitives table, OneDev repo link, phase roadmap
- [x] `agents/termlink/termlink.sh` implements 8 subcommands adapted from tl-dispatch.sh
- [x] `fw termlink` routes to `agents/termlink/termlink.sh`
- [x] `fw help` lists termlink command
- [x] CLAUDE.md has TermLink section with commands, budget rule, cleanup rule

### Human
- [ ] [RUBBER-STAMP] Run `fw doctor` and verify TermLink check appears
  **Steps:**
  1. Run `fw doctor` in framework repo
  2. Look for TermLink line (OK if installed, WARN if not)
  **Expected:** Line shows "TermLink not installed (cargo install termlink)" or version
  **If not:** Check bin/fw do_doctor for the TermLink check block

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

### 2026-03-15T23:58:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-503-termlink-phase-0-build--doctor-check-age.md
- **Context:** Initial task creation
