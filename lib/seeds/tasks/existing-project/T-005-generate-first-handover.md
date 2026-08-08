---
id: T-005
name: "Generate first session handover for __PROJECT_NAME__"
description: >
  Practice the session end protocol: generate a handover document that captures current
  state, work in progress, and suggested next actions for __PROJECT_NAME__.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-005: Generate first session handover for __PROJECT_NAME__

## Context

The handover is the primary mechanism for session continuity. Generate one now to validate the process and establish a baseline for future sessions.

## For the Operator

**What is happening:** the agent writes a handover — where the work stands, what is in
flight, what the next session should pick up first.

**Why it matters to you:** an agent's memory ends when its context window does. The handover
is what survives that. It is also what *you* read after a week away to reload
__PROJECT_NAME__ without re-reading the code. If the handover is vague, every session after
it starts vague — which is why the framework refuses to leave `[TODO]` placeholders in one.

**What you can do meanwhile:** read it. If it does not tell you what you would need to know
cold, say so — that is exactly the feedback the format wants, and it is easier to fix the
first one than the fiftieth.

**Go deeper:** `fw corpus explain aef-session-lifecycle` — where handover sits in the shape
of a session.

## Acceptance Criteria

### Agent
- [ ] Run `fw handover --commit` to generate and commit the handover
- [ ] Handover saved to `.context/handovers/LATEST.md`
- [ ] All [TODO] sections filled in (not left as placeholders)

## Verification

# Handover exists
test -f .context/handovers/LATEST.md
# No unfilled TODOs in handover
test "$(grep -c '\[TODO' .context/handovers/LATEST.md || true)" = "0"
