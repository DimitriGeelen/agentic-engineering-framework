---
id: T-005
name: "Generate first session handover for __PROJECT_NAME__"
description: >
  Practice the session end protocol: generate a handover document that captures state,
  work in progress, and next actions.
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

The handover is the primary mechanism for session continuity. Generate one to validate the process and establish a baseline.

## For the Operator

**What is happening:** the last step of the prologue. The agent writes a handover — a
document describing where the work stands, what is in flight, and what the next session
should pick up first.

**Why it matters to you:** an agent's memory ends when its context window does. The
handover is what survives that. It is also what *you* read after a week away to reload the
project without re-reading the code. If the handover is vague, every subsequent session
starts vague — which is why the framework refuses to leave `[TODO]` placeholders in it.

**After this task closes, the prologue is over.** The gate that has been holding the agent
to onboarding work lifts, and the agent starts on whatever you actually came here to build.
That is the moment this curriculum exists for: you should now have enough of the model to
follow along, disagree, and redirect.

**What you can do meanwhile:** read the handover it produces. If it does not tell you what
you would need to know cold, say so — that is exactly the feedback the format wants.

**Go deeper:** `fw corpus explain aef-session-lifecycle` — where handover sits in the shape
of a session. And if you want the whole picture at once, open Watchtower `/designer` and
browse the maps directly.

## Acceptance Criteria

### Agent
- [ ] Run `fw handover --commit` to generate and commit the handover
- [ ] Handover saved to `.context/handovers/LATEST.md`
- [ ] All [TODO] sections filled in

## Verification

# Handover exists
test -f .context/handovers/LATEST.md

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
